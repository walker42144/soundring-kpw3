"""SoundRing KPW3 configuration prototype. No automatic Kindle installation."""
import base64, hashlib, ipaddress, json, os, re, secrets, shutil, tempfile, threading, time, webbrowser
try:
    import tkinter as tk
    from tkinter import filedialog, messagebox, ttk
except ModuleNotFoundError:
    tk = filedialog = messagebox = ttk = None
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlencode, urlparse, parse_qs
from urllib.request import Request, urlopen

REDIRECT = 'http://127.0.0.1:8765/callback'
SCOPES = 'user-read-playback-state user-read-currently-playing user-modify-playback-state playlist-read-private playlist-read-collaborative user-library-read user-library-modify'

def validate_redirect(value):
    try:
        parsed=urlparse(value)
        if (parsed.scheme != 'http' or not parsed.hostname or not parsed.port
            or not ipaddress.IPv4Address(parsed.hostname).is_loopback
            or not parsed.path.startswith('/') or parsed.params or parsed.query or parsed.fragment
            or parsed.username or parsed.password or any(c.isspace() for c in value)):
            raise ValueError()
        return parsed
    except (ValueError, AttributeError):
        raise ValueError('请输入本机 IPv4 回调地址，例如 http://127.0.0.1:8765/callback，并包含端口和路径。')

def authorize(client_id, redirect_uri=REDIRECT):
    if not client_id.strip(): raise ValueError('请填写已有的 Spotify Client ID。')
    redirect_uri=redirect_uri.strip();redirect=validate_redirect(redirect_uri)
    verifier=base64.urlsafe_b64encode(os.urandom(48)).decode().rstrip('=')
    challenge=base64.urlsafe_b64encode(hashlib.sha256(verifier.encode()).digest()).decode().rstrip('=')
    state=secrets.token_urlsafe(24); result={}
    class Handler(BaseHTTPRequestHandler):
        def log_message(self,*args): pass
        def do_GET(self):
            p=urlparse(self.path); q=parse_qs(p.query)
            if p.path!=redirect.path or not secrets.compare_digest(q.get('state',[''])[0],state):
                self.send_error(400);return
            result['code']=q.get('code',[''])[0];result['error']=q.get('error',[''])[0]
            body='授权结果已收到，请返回配置工具。'.encode('utf-8')
            self.send_response(200);self.send_header('Content-Type','text/plain; charset=utf-8');self.send_header('Content-Length',str(len(body)));self.end_headers();self.wfile.write(body)
    server=HTTPServer((redirect.hostname,redirect.port),Handler);server.timeout=1
    try:
        params={'client_id':client_id.strip(),'response_type':'code','redirect_uri':redirect_uri,'scope':SCOPES,'state':state,'code_challenge_method':'S256','code_challenge':challenge}
        url='https://accounts.spotify.com/authorize?'+urlencode(params)
        if not webbrowser.open(url): raise RuntimeError('无法打开浏览器。')
        deadline=time.monotonic()+240
        while not result and time.monotonic()<deadline: server.handle_request()
    finally: server.server_close()
    if not result.get('code') or result.get('error'): raise RuntimeError('授权未完成或已超时。')
    body=urlencode({'grant_type':'authorization_code','code':result['code'],'redirect_uri':redirect_uri,'client_id':client_id.strip(),'code_verifier':verifier}).encode()
    with urlopen(Request('https://accounts.spotify.com/api/token',data=body,headers={'Content-Type':'application/x-www-form-urlencoded'}),timeout=30) as resp:
        token=json.load(resp)
    if not token.get('access_token') or not token.get('refresh_token'): raise RuntimeError('Spotify 未返回完整令牌。')
    return {'client_id':client_id.strip(),'redirect_uri':redirect_uri,'access_token':token['access_token'],'refresh_token':token['refresh_token'],'scope':token.get('scope',SCOPES),'expires_at_ms':int(time.time()*1000)+int(token.get('expires_in',3600))*1000}

def write_json(path, value):
    directory=os.path.dirname(os.path.abspath(path));fd,tmp=tempfile.mkstemp(prefix='.soundring-',suffix='.tmp',dir=directory)
    try:
        with os.fdopen(fd,'w',encoding='utf-8') as out: json.dump(value,out,ensure_ascii=False,indent=2)
        os.replace(tmp,path)
    finally:
        if os.path.exists(tmp): os.remove(tmp)

def export_device_config(root, config, token):
    root=os.path.abspath(root)
    if not os.path.isdir(os.path.join(root,'documents')):
        raise ValueError('请选择 Kindle USB 存储根目录，其中应包含 documents 文件夹。')
    target=os.path.join(root,'soundring')
    if os.path.islink(target): raise ValueError('目标目录不能是符号链接。')
    os.makedirs(target,exist_ok=True)
    paths=[os.path.join(target,'soundring-config.json'),os.path.join(target,'soundring-token.json')]
    if any(os.path.islink(p) for p in paths): raise ValueError('目标文件不能是符号链接。')
    if any(os.path.exists(p) and not os.path.isfile(p) for p in paths): raise ValueError('目标路径已被非文件对象占用。')
    old=[os.path.isfile(p) for p in paths];backup=None
    if any(old):
        backup=tempfile.mkdtemp(prefix='soundring-config-backup-')
        for exists,path in zip(old,paths):
            if exists: shutil.copy2(path,os.path.join(backup,os.path.basename(path)))
    try:
        write_json(paths[0],config);write_json(paths[1],token)
    except Exception:
        for exists,path in zip(old,paths):
            if exists: shutil.copy2(os.path.join(backup,os.path.basename(path)),path)
            elif os.path.exists(path): os.remove(path)
        raise
    return paths,backup

def recover_lyric_choices(root):
    """Recover validated manual selections from local cache; preserve the original."""
    root=os.path.abspath(root);target=os.path.join(root,'soundring')
    if not os.path.isdir(os.path.join(root,'documents')) or os.path.islink(target): raise ValueError('请选择 Kindle 存储根目录。')
    path=os.path.join(target,'lyric-choices.json');cache=os.path.join(target,'lyrics-cache')
    if os.path.islink(path) or os.path.islink(cache): raise ValueError('数据路径不能是符号链接。')
    if os.path.exists(path):
        if not os.path.isfile(path): raise ValueError('歌词选择路径不是普通文件。')
        try:
            with open(path,'r',encoding='utf8') as f: old=json.load(f)
            if isinstance(old,dict): raise ValueError('现有歌词选择文件有效，无需恢复。')
        except (json.JSONDecodeError,UnicodeDecodeError): pass
    if not os.path.isdir(cache): raise ValueError('没有找到歌词缓存目录。')
    recovered={}
    for item in os.scandir(cache):
        if not item.is_file(follow_symlinks=False) or not re.fullmatch(r'[A-Za-z0-9]{1,64}\.json',item.name): continue
        try:
            if item.stat(follow_symlinks=False).st_size>1100000: continue
            with open(item.path,'r',encoding='utf8') as f: data=json.load(f)
            ident=item.name[:-5];c=data.get('choice') if isinstance(data,dict) and data.get('version')==1 and data.get('track_id')==ident else None
            if not isinstance(c,dict) or c.get('source') not in ('qq','netease') or not isinstance(c.get('id'),str) or not re.fullmatch(r'[A-Za-z0-9]{1,32}',c['id']): continue
            if c['source']=='netease' and not re.fullmatch(r'[0-9]+',c['id']): continue
            if data.get('source')!=c['source'] or not isinstance(data.get('lrc'),str) or not re.search(r'\[\d+:\d+[\d.]*\]',data['lrc']): continue
            recovered[ident]={'source':c['source'],'id':c['id']}
        except (OSError,UnicodeDecodeError,ValueError,TypeError): continue
    if not recovered: raise ValueError('没有可验证的手动歌词缓存，未修改原文件。')
    if len(json.dumps(recovered,ensure_ascii=False).encode('utf8'))>262144: raise ValueError('恢复结果超过容量限制，未修改原文件。')
    backup=None
    if os.path.exists(path):
        backup=path+'.damaged-'+secrets.token_hex(8)+'.bak'
        with open(path,'rb') as source,open(backup,'xb') as dest: shutil.copyfileobj(source,dest)
    write_json(path,recovered)
    return len(recovered),backup

def scan_automatic_lyrics(root):
    """List only validated, automatically fetched entries, without modifying them."""
    root=os.path.abspath(root);base=os.path.join(root,'soundring');cache=os.path.join(base,'lyrics-cache');index=os.path.join(base,'lyric-choices.json')
    if not os.path.isdir(os.path.join(root,'documents')) or os.path.islink(base) or os.path.islink(cache) or os.path.islink(index): raise ValueError('请选择有效的 Kindle 存储根目录。')
    if not os.path.isdir(cache): return {'index':index,'index_hash':None,'files':[],'bytes':0}
    selected={};index_hash=None
    if os.path.exists(index):
        if not os.path.isfile(index) or os.path.getsize(index)>262144: raise ValueError('手动歌词选择索引不可读取，已停止清理。')
        with open(index,'rb') as f: raw=f.read(262145)
        try: selected=json.loads(raw.decode('utf8'))
        except (ValueError,UnicodeDecodeError): raise ValueError('手动歌词选择索引损坏，已停止清理。')
        if not isinstance(selected,dict): raise ValueError('手动歌词选择索引损坏，已停止清理。')
        index_hash=hashlib.sha256(raw).hexdigest()
    files=[];size=0
    for item in os.scandir(cache):
        if not item.is_file(follow_symlinks=False) or not re.fullmatch(r'[A-Za-z0-9]{1,64}\.json',item.name): continue
        ident=item.name[:-5]
        if ident in selected:continue
        try:
            stat=item.stat(follow_symlinks=False)
            if stat.st_size>1100000:continue
            with open(item.path,'r',encoding='utf8') as f: data=json.load(f)
            if not isinstance(data,dict) or data.get('version')!=1 or data.get('track_id')!=ident or data.get('choice') is not None:continue
            if data.get('source') not in ('qq','netease') or not isinstance(data.get('lrc'),str) or not re.search(r'\[\d+:\d+[\d.]*\]',data['lrc']):continue
            files.append((item.path,stat.st_size,stat.st_mtime_ns));size+=stat.st_size
        except (OSError,UnicodeDecodeError,ValueError,TypeError):continue
    return {'index':index,'index_hash':index_hash,'files':files,'bytes':size}

def remove_automatic_lyrics(plan):
    """Remove reviewed entries only if the manual-choice index and files are unchanged."""
    index=plan['index']
    if os.path.islink(index):raise ValueError('歌词选择索引已变化，请重新扫描。')
    if os.path.isfile(index):
        with open(index,'rb') as f: current=hashlib.sha256(f.read(262145)).hexdigest()
    elif os.path.exists(index):raise ValueError('歌词选择索引已变化，请重新扫描。')
    else:current=None
    if current!=plan['index_hash']:raise ValueError('歌词选择索引已变化，请重新扫描。')
    removed=0
    for path,size,mtime in plan['files']:
        try:
            if os.path.islink(path):continue
            stat=os.stat(path,follow_symlinks=False)
            if stat.st_size!=size or stat.st_mtime_ns!=mtime:continue
            os.unlink(path);removed+=1
        except FileNotFoundError:continue
    return removed

class App:
    def __init__(self, root):
        self.root=root;root.title('SoundRing KPW3 配置工具');root.geometry('680x640');root.minsize(560,620)
        self.client=tk.StringVar();self.redirect=tk.StringVar(value=REDIRECT);self.source=tk.StringVar(value='qq_netease_local');self.interval=tk.IntVar(value=5);self.token=None
        frame=ttk.Frame(root,padding=24);frame.pack(fill='both',expand=True)
        ttk.Label(frame,text='SoundRing KPW3',font=('Microsoft YaHei UI',18,'bold')).pack(anchor='w')
        ttk.Label(frame,text='使用已有的 Spotify 应用授权，并将配置写入 Kindle。',wraplength=610).pack(anchor='w',pady=(5,18))
        box=ttk.LabelFrame(frame,text='Spotify 授权',padding=12);box.pack(fill='x')
        ttk.Label(box,text='已有 Client ID').grid(row=0,column=0,sticky='w');ttk.Entry(box,textvariable=self.client,width=46).grid(row=0,column=1,sticky='ew',padx=(12,0))
        ttk.Label(box,text='回调地址').grid(row=1,column=0,sticky='w',pady=8);ttk.Entry(box,textvariable=self.redirect,width=46).grid(row=1,column=1,sticky='ew',padx=(12,0));box.columnconfigure(1,weight=1)
        self.auth=ttk.Button(box,text='在浏览器中授权',command=self.start_auth);self.auth.grid(row=2,column=1,sticky='w',padx=12,pady=4)
        self.status=ttk.Label(box,text='尚未授权');self.status.grid(row=3,column=1,sticky='w',padx=12)
        opts=ttk.LabelFrame(frame,text='歌词与刷新',padding=12);opts.pack(fill='x',pady=14)
        ttk.Radiobutton(opts,text='QQ 音乐优先 → 网易云 → 本地 LRC',variable=self.source,value='qq_netease_local').pack(anchor='w');ttk.Radiobutton(opts,text='仅使用本地 LRC',variable=self.source,value='local').pack(anchor='w')
        line=ttk.Frame(opts);line.pack(fill='x',pady=(10,0));ttk.Label(line,text='播放状态查询间隔（秒）').pack(side='left');ttk.Spinbox(line,from_=5,to=120,textvariable=self.interval,width=5).pack(side='left',padx=10)
        ttk.Label(frame,text='导出的授权文件包含可访问账号的令牌，请只保存在你信任的位置。',wraplength=610).pack(anchor='w',pady=(0,12))
        buttons=ttk.Frame(frame);buttons.pack(fill='x');ttk.Button(buttons,text='导出配置',command=self.export_config).pack(side='left');ttk.Button(buttons,text='导出授权文件',command=self.export_token).pack(side='left',padx=10);ttk.Button(buttons,text='写入 Kindle 配置',command=self.export_to_device).pack(side='left')
        maintenance=ttk.Frame(frame);maintenance.pack(fill='x',pady=(10,0));ttk.Button(maintenance,text='从缓存恢复损坏的歌词选择',command=self.recover_choices).pack(side='left');ttk.Button(maintenance,text='清理自动歌词缓存',command=self.clean_lyrics).pack(side='left',padx=10)
    def clean_lyrics(self):
        root=filedialog.askdirectory(title='选择 Kindle USB 存储根目录')
        if not root:return
        try: plan=scan_automatic_lyrics(root)
        except (OSError,ValueError) as e:messagebox.showerror('无法扫描',str(e),parent=self.root);return
        if not plan['files']:messagebox.showinfo('没有可清理的缓存','未发现可安全清理的自动歌词缓存。',parent=self.root);return
        if not messagebox.askyesno('确认清理',f"将删除 {len(plan['files'])} 个自动歌词缓存，约 {plan['bytes']/1048576:.1f} MiB。手动选择、损坏或不可验证的文件会保留。继续吗？",parent=self.root):return
        try: count=remove_automatic_lyrics(plan)
        except (OSError,ValueError) as e:messagebox.showerror('清理中止',str(e),parent=self.root);return
        messagebox.showinfo('清理完成',f'已清理 {count} 个未改变的自动缓存。',parent=self.root)
    def recover_choices(self):
        root=filedialog.askdirectory(title='选择 Kindle USB 存储根目录')
        if not root:return
        if not messagebox.askyesno('恢复歌词选择','仅从可验证的歌词缓存恢复手动选择；原损坏文件会保存在 Kindle。无法从缓存恢复的选择仍需要重新选择。继续吗？',parent=self.root):return
        try: count,backup=recover_lyric_choices(root)
        except (OSError,ValueError) as e:messagebox.showerror('无法恢复',str(e),parent=self.root);return
        messagebox.showinfo('恢复完成',f'恢复了 {count} 条歌词选择。'+('\n原文件备份：'+backup if backup else ''),parent=self.root)
    def start_auth(self):
        client=self.client.get().strip();redirect_uri=self.redirect.get().strip();self.auth.config(state='disabled');self.status.config(text='等待浏览器授权…')
        def worker():
            try:
                value=authorize(client,redirect_uri)
            except Exception as exc:
                error=str(exc);self.root.after(0,lambda:self.finish(None,error))
            else: self.root.after(0,lambda:self.finish(value,None))
        threading.Thread(target=worker,daemon=True).start()
    def finish(self,value,error):
        self.auth.config(state='normal');self.token=value
        self.status.config(text='授权完成，可导出授权文件' if value else '授权未完成')
        if error: messagebox.showerror('授权失败',error,parent=self.root)
    def export_config(self):
        try:
            interval=int(self.interval.get())
            if not 5<=interval<=120: raise ValueError()
        except (ValueError,tk.TclError): messagebox.showerror('配置错误','刷新间隔须在 5 到 120 秒之间。',parent=self.root);return
        try: redirect_uri=self.redirect.get().strip();validate_redirect(redirect_uri)
        except ValueError as e: messagebox.showerror('回调地址错误',str(e),parent=self.root);return
        path=filedialog.asksaveasfilename(title='导出配置',defaultextension='.json',initialfile='soundring-config.json',filetypes=[('JSON','*.json')])
        if path:
            try: write_json(path,{'client_id':self.client.get().strip(),'redirect_uri':redirect_uri,'lyrics_source':self.source.get(),'refresh_seconds':interval})
            except OSError as e: messagebox.showerror('保存失败',str(e),parent=self.root)
    def export_token(self):
        if not self.token: messagebox.showinfo('尚未授权','请先完成 Spotify 授权。',parent=self.root);return
        if self.token['client_id']!=self.client.get().strip() or self.token['redirect_uri']!=self.redirect.get().strip():
            messagebox.showerror('授权已变化','Client ID 或回调地址已更改，请重新授权。',parent=self.root);return
        path=filedialog.asksaveasfilename(title='导出敏感授权文件',defaultextension='.json',initialfile='soundring-token.json',filetypes=[('JSON','*.json')])
        if path:
            try: write_json(path,self.token)
            except OSError as e: messagebox.showerror('保存失败',str(e),parent=self.root)

    def export_to_device(self):
        if not self.token: messagebox.showinfo('尚未授权','请先完成 Spotify 授权。',parent=self.root);return
        client=self.client.get().strip();redirect=self.redirect.get().strip()
        if self.token['client_id']!=client or self.token['redirect_uri']!=redirect:
            messagebox.showerror('授权已变化','Client ID 或回调地址已更改，请重新授权。',parent=self.root);return
        try:
            validate_redirect(redirect);interval=int(self.interval.get())
            if not 5<=interval<=120: raise ValueError('刷新间隔须在 5 到 120 秒之间。')
        except (ValueError,tk.TclError) as e: messagebox.showerror('配置错误',str(e),parent=self.root);return
        root=filedialog.askdirectory(title='选择 Kindle USB 存储根目录')
        if not root: return
        target=os.path.join(os.path.abspath(root),'soundring')
        if not os.path.isdir(os.path.join(root,'documents')):
            messagebox.showerror('未找到 Kindle 目录','所选目录应包含 documents 文件夹。',parent=self.root);return
        prompt='将写入以下两个文件：\n'+os.path.join(target,'soundring-config.json')+'\n'+os.path.join(target,'soundring-token.json')+'\n\n已有文件会先备份到电脑的临时目录。备份及授权文件均包含敏感令牌。'
        if not messagebox.askyesno('确认写入目标',prompt,parent=self.root): return
        cfg={'client_id':client,'redirect_uri':redirect,'lyrics_source':self.source.get(),'refresh_seconds':interval}
        try: paths,backup=export_device_config(root,cfg,self.token)
        except (OSError,ValueError) as e: messagebox.showerror('写入失败',str(e),parent=self.root);return
        messagebox.showinfo('配置已写入','配置和授权已写入。'+('\n备份：'+backup if backup else '')+'\n请安全弹出 Kindle。',parent=self.root)

if __name__=='__main__':
    if tk is None: raise SystemExit('Tkinter is required to run the configuration UI.')
    root=tk.Tk();App(root);root.mainloop()
