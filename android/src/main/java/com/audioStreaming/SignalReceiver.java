package com.audioStreaming;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

import java.util.Objects;

class SignalReceiver extends BroadcastReceiver {
    private final Signal signal;

    public SignalReceiver(Signal signal) {
        super();
        this.signal = signal;
    }

    @Override
    public void onReceive(Context context, Intent intent) {
        String action = intent.getAction();

        if ( Objects.equals(action, Signal.BROADCAST_PLAYBACK_PLAY) ) {
            if (!this.signal.isPlaying()) {
                this.signal.resume();
            } else {
                this.signal.pause();
            }
        } else if (action.equals(Signal.BROADCAST_EXIT)) {
            this.signal.stop();
        }
    }
}
