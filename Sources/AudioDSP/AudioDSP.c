#include "AudioDSP.h"
#include <stdatomic.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
struct MixerState { _Atomic(float) target; float current; _Atomic(unsigned long) ticks; _Atomic(int) failed; };
MixerState *mixer_create(void) { MixerState *s=calloc(1,sizeof(*s)); if(!s) return NULL; s->target=1; s->current=1; return s; }
void mixer_free(MixerState *s) { free(s); }
void mixer_gain(MixerState *s,float g) { atomic_store(&s->target,isfinite(g)?fmaxf(0,fminf(1,g)):0); }
unsigned long mixer_ticks(MixerState *s) { return atomic_load(&s->ticks); }
int mixer_failed(MixerState *s) { return atomic_load(&s->failed); }
OSStatus mixer_io(AudioDeviceID d,const AudioTimeStamp *a,const AudioBufferList *in,const AudioTimeStamp *b,AudioBufferList *out,const AudioTimeStamp *c,void *ctx) {
 MixerState *s=ctx;
 for(unsigned j=0;j<out->mNumberBuffers;j++) if(out->mBuffers[j].mData) memset(out->mBuffers[j].mData,0,out->mBuffers[j].mDataByteSize);
 // Supported topology deliberately narrow: matching Float32 stereo tap/output layouts, no physical inputs.
 if(in->mNumberBuffers!=out->mNumberBuffers) { atomic_store(&s->failed,1); return noErr; }
 for(unsigned j=0;j<out->mNumberBuffers;j++) if(!in->mBuffers[j].mData || !out->mBuffers[j].mData || in->mBuffers[j].mDataByteSize!=out->mBuffers[j].mDataByteSize || in->mBuffers[j].mNumberChannels!=out->mBuffers[j].mNumberChannels) { atomic_store(&s->failed,1); return noErr; }
 float target=atomic_load(&s->target), start=s->current;
 for(unsigned j=0;j<out->mNumberBuffers;j++) { unsigned n=out->mBuffers[j].mDataByteSize/sizeof(float), ch=out->mBuffers[j].mNumberChannels; float *dst=out->mBuffers[j].mData; const float *src=in->mBuffers[j].mData; unsigned frames=ch?n/ch:0;
 for(unsigned i=0;i<n;i++) dst[i]=src[i]*(start+(target-start)*(float)(i/ch+1)/(float)frames);
 }
 s->current=target; atomic_fetch_add(&s->ticks,1); return noErr;
}
