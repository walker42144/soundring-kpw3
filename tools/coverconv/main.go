// coverconv decodes an image and creates a bounded 8-bit grayscale raster.
// The full source image is contained without crop or overlays.
package main
import (
 "bufio"
 "fmt"
 "image"
 _ "image/jpeg"
 _ "image/png"
 "os"
 "strconv"
)
func run() error {
 if len(os.Args)!=5 { return fmt.Errorf("usage: coverconv input output width height") }
 w,e:=strconv.Atoi(os.Args[3]);if e!=nil||w<1||w>600{return fmt.Errorf("invalid width")};h,e:=strconv.Atoi(os.Args[4]);if e!=nil||h<1||h>600{return fmt.Errorf("invalid height")}
 f,e:=os.Open(os.Args[1]);if e!=nil{return e};defer f.Close(); st,e:=f.Stat();if e!=nil||st.Size()>2<<20{return fmt.Errorf("image too large")}
 cfg,_,e:=image.DecodeConfig(f);if e!=nil||cfg.Width<1||cfg.Height<1||cfg.Width>4096||cfg.Height>4096||int64(cfg.Width)*int64(cfg.Height)>12000000{return fmt.Errorf("invalid image")}
 if _,e=f.Seek(0,0);e!=nil{return e};src,_,e:=image.Decode(f);if e!=nil{return e}
 tmp:=os.Args[2]+".tmp";out,e:=os.OpenFile(tmp,os.O_WRONLY|os.O_CREATE|os.O_TRUNC,0600);if e!=nil{return e};defer os.Remove(tmp)
 bw:=bufio.NewWriter(out);bounds:=src.Bounds();sw,sh:=bounds.Dx(),bounds.Dy();dw,dh:=w,h
 if sw*h>sh*w {dh=sh*w/sw}else{dw=sw*h/sh};if dw<1{dw=1};if dh<1{dh=1};ox,oy:=(w-dw)/2,(h-dh)/2
 row:=make([]byte,w);for y:=0;y<h;y++{for x:=0;x<w;x++{row[x]=255;if x>=ox&&x<ox+dw&&y>=oy&&y<oy+dh{r,g,b,a:=src.At(bounds.Min.X+(x-ox)*sw/dw,bounds.Min.Y+(y-oy)*sh/dh).RGBA(); if a>0 { row[x]=byte(((299*r+587*g+114*b)/1000+(65535-a))>>8) }}};if _,e=bw.Write(row);e!=nil{out.Close();return e}}
 if e=bw.Flush();e!=nil{out.Close();return e};if e=out.Close();e!=nil{return e};return os.Rename(tmp,os.Args[2])
}
func main(){if err:=run();err!=nil{fmt.Fprintln(os.Stderr,err);os.Exit(1)}}
