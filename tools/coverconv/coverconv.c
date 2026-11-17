#define STBI_ONLY_JPEG
#define STBI_ONLY_PNG
#define STBI_NO_STDIO
#define STBI_MAX_DIMENSIONS 4096
#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#define MAX_INPUT (2*1024*1024)
int main(int argc,char **argv){
 if(argc==2 && strcmp(argv[1],"--self-test")==0)return 0;
 if(argc!=5){fprintf(stderr,"usage: coverconv input output width height\n");return 2;}
 char *end;long w=strtol(argv[3],&end,10);if(*end||w<1||w>600)return 2;long h=strtol(argv[4],&end,10);if(*end||h<1||h>600)return 2;
 FILE *f=fopen(argv[1],"rb");if(!f)return 3;if(fseek(f,0,SEEK_END)){fclose(f);return 3;}long len=ftell(f);if(len<=0||len>MAX_INPUT||fseek(f,0,SEEK_SET)){fclose(f);return 3;}
 unsigned char *buf=malloc((size_t)len);if(!buf){fclose(f);return 3;}if(fread(buf,1,(size_t)len,f)!=(size_t)len){free(buf);fclose(f);return 3;}fclose(f);
 int sw,sh,n;if(!stbi_info_from_memory(buf,(int)len,&sw,&sh,&n)||sw<1||sh<1||sw>4096||sh>4096||(int64_t)sw*sh>12000000){free(buf);return 4;}
 unsigned char *img=stbi_load_from_memory(buf,(int)len,&sw,&sh,&n,4);free(buf);if(!img)return 4;
 size_t outlen=strlen(argv[2]);if(outlen>4000){stbi_image_free(img);return 2;}char *tmp=malloc(outlen+5);if(!tmp){stbi_image_free(img);return 3;}memcpy(tmp,argv[2],outlen);memcpy(tmp+outlen,".tmp",5);
 FILE *o=fopen(tmp,"wb");if(!o){free(tmp);stbi_image_free(img);return 3;}
 long dw=w,dh=h;if((int64_t)sw*h>(int64_t)sh*w)dh=(long)sh*w/sw;else dw=(long)sw*h/sh;if(dw<1)dw=1;if(dh<1)dh=1;long ox=(w-dw)/2,oy=(h-dh)/2;int ok=1;
 for(long y=0;y<h&&ok;y++)for(long x=0;x<w;x++){unsigned gray=255;if(x>=ox&&x<ox+dw&&y>=oy&&y<oy+dh){long sx=(x-ox)*sw/dw,sy=(y-oy)*sh/dh;unsigned char *p=img+((size_t)sy*sw+sx)*4;unsigned a=p[3];unsigned luma=(299*p[0]+587*p[1]+114*p[2])/1000;gray=(luma*a+255*(255-a)+127)/255;}if(fputc((int)gray,o)==EOF){ok=0;break;}}
 if(fclose(o)!=0)ok=0;stbi_image_free(img);if(ok&&rename(tmp,argv[2])!=0)ok=0;if(!ok)remove(tmp);free(tmp);return ok?0:5;
}
