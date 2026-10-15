#include <CoreAudio/CoreAudio.h>
typedef struct MixerState MixerState;
MixerState * _Nullable mixer_create(void);
void mixer_free(MixerState * _Nonnull s);
void mixer_gain(MixerState * _Nonnull s, float gain);
unsigned long mixer_ticks(MixerState * _Nonnull s);
int mixer_failed(MixerState * _Nonnull s);
OSStatus mixer_io(AudioDeviceID, const AudioTimeStamp * _Nonnull, const AudioBufferList * _Nonnull, const AudioTimeStamp * _Nonnull, AudioBufferList * _Nonnull, const AudioTimeStamp * _Nonnull, void * _Nullable);
