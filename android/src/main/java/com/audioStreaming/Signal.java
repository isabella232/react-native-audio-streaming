package com.audioStreaming;

import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.media.AudioManager;
import android.net.ConnectivityManager;
import android.net.NetworkInfo;
import android.net.Uri;
import android.os.Binder;
import android.os.Handler;
import android.os.IBinder;
import android.util.Log;

import com.google.android.exoplayer2.ExoPlaybackException;
import com.google.android.exoplayer2.ExoPlayer;
import com.google.android.exoplayer2.ExoPlayerFactory;
import com.google.android.exoplayer2.PlaybackParameters;
import com.google.android.exoplayer2.SimpleExoPlayer;
import com.google.android.exoplayer2.Timeline;
import com.google.android.exoplayer2.extractor.DefaultExtractorsFactory;
import com.google.android.exoplayer2.extractor.ExtractorsFactory;
import com.google.android.exoplayer2.metadata.Metadata;
import com.google.android.exoplayer2.metadata.MetadataRenderer;
import com.google.android.exoplayer2.source.ExtractorMediaSource;
import com.google.android.exoplayer2.source.MediaSource;
import com.google.android.exoplayer2.source.TrackGroupArray;
import com.google.android.exoplayer2.trackselection.DefaultTrackSelector;
import com.google.android.exoplayer2.trackselection.TrackSelectionArray;
import com.google.android.exoplayer2.trackselection.TrackSelector;
import com.google.android.exoplayer2.upstream.DataSource;
import com.google.android.exoplayer2.upstream.DefaultBandwidthMeter;
import com.google.android.exoplayer2.upstream.DefaultDataSourceFactory;
import com.google.android.exoplayer2.util.Util;

import java.io.IOException;
import java.util.concurrent.TimeUnit;

public class Signal extends Service implements ExoPlayer.EventListener, MetadataRenderer.Output, ExtractorMediaSource.EventListener {
    private static final String TAG = "RNAudioStreaming";

    private DataSource.Factory dataSourceFactory;
    private SimpleExoPlayer player = null;

    private static final String BROADCAST_PLAYBACK_STOP = "stop";
    public static final String BROADCAST_PLAYBACK_PLAY = "pause";
    public static final String BROADCAST_EXIT = "exit";

    private final IBinder binder = new RadioBinder();
    private final SignalReceiver receiver = new SignalReceiver(this);
    private Context context;
    private String streamingURL;
    private final Handler mHandler = new Handler();

    private final AudioManager.OnAudioFocusChangeListener afChangeListener =
            new AudioManager.OnAudioFocusChangeListener() {
                public void onAudioFocusChange(int focusChange) {
                    if (focusChange == AudioManager.AUDIOFOCUS_LOSS) {
                        // Permanent loss of audio focus
                        // Pause playback immediately
                        pause();
                        // Wait 30 seconds before stopping playback
                        mHandler.postDelayed(mDelayedStopRunnable,
                                TimeUnit.SECONDS.toMillis(30));
                    }
                    else if (focusChange == AudioManager.AUDIOFOCUS_LOSS_TRANSIENT) {
                        pause();
                    } else if (focusChange == AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK) {
                        // Lower the volume, keep playing
                    } else if (focusChange == AudioManager.AUDIOFOCUS_GAIN) {
                        // Your app has been granted audio focus again
                        // Raise volume to normal, restart playback if necessary
                        resume();
                    }
                }
            };

    private final Runnable mDelayedStopRunnable = new Runnable() {
        @Override
        public void run() {
            stop();
        }
    };

    private final Runnable mProgressTickRunnable = new Runnable() {
        @Override
        public void run() {
            if ( (player != null) && (player.getPlaybackState() == ExoPlayer.STATE_READY) && player.getPlayWhenReady() ) {
                double position = (getCurrentPosition() / 1000);
                double duration = (getDuration() / 1000);
                Intent StreamingIntent = new Intent(Mode.STREAMING);
                StreamingIntent.putExtra("progress", position);
                StreamingIntent.putExtra("duration", duration);
                sendBroadcast(StreamingIntent);
                mHandler.postDelayed(mProgressTickRunnable, 1000);
            }
        }
    };

    @Override
    public void onCreate() {
        IntentFilter intentFilter = new IntentFilter();
        intentFilter.addAction(BROADCAST_PLAYBACK_STOP);
        intentFilter.addAction(BROADCAST_PLAYBACK_PLAY);
        intentFilter.addAction(BROADCAST_EXIT);
        registerReceiver(this.receiver, intentFilter);
    }

    @Override
    public void onPlaybackParametersChanged(PlaybackParameters playbackParameters) {

    }

    @Override
    public void onTracksChanged(TrackGroupArray trackGroups, TrackSelectionArray trackSelections) {

    }

    public void setData(Context context, ReactNativeAudioStreamingModule module) {
        this.context = context;
        // ReactNativeAudioStreamingModule module1 = module;

        EventsReceiver eventsReceiver = new EventsReceiver(module);

        registerReceiver(eventsReceiver, new IntentFilter(Mode.CREATED));
        registerReceiver(eventsReceiver, new IntentFilter(Mode.IDLE));
        registerReceiver(eventsReceiver, new IntentFilter(Mode.DESTROYED));
        registerReceiver(eventsReceiver, new IntentFilter(Mode.STARTED));
        registerReceiver(eventsReceiver, new IntentFilter(Mode.CONNECTING));
        registerReceiver(eventsReceiver, new IntentFilter(Mode.PLAYING));
        registerReceiver(eventsReceiver, new IntentFilter(Mode.READY));
        registerReceiver(eventsReceiver, new IntentFilter(Mode.STOPPED));
        registerReceiver(eventsReceiver, new IntentFilter(Mode.PAUSED));
        registerReceiver(eventsReceiver, new IntentFilter(Mode.COMPLETED));
        registerReceiver(eventsReceiver, new IntentFilter(Mode.ERROR));
        registerReceiver(eventsReceiver, new IntentFilter(Mode.BUFFERING));
        registerReceiver(eventsReceiver, new IntentFilter(Mode.BUFFERING_END));
        registerReceiver(eventsReceiver, new IntentFilter(Mode.METADATA_UPDATED));
        registerReceiver(eventsReceiver, new IntentFilter(Mode.ALBUM_UPDATED));
        registerReceiver(eventsReceiver, new IntentFilter(Mode.STREAMING));
    }

    @Override
    public void onLoadingChanged(boolean isLoading) {

    }

    @Override
    public void onPlayerStateChanged(boolean playWhenReady, int playbackState) {

        removeProgressListener();

        switch (playbackState) {
            case ExoPlayer.STATE_IDLE:
                sendBroadcast(new Intent(Mode.IDLE));
                break;
            case ExoPlayer.STATE_BUFFERING:
                sendBroadcast(new Intent(Mode.BUFFERING));
                break;
            case ExoPlayer.STATE_READY:
                if ( this.player != null && this.player.getPlayWhenReady() ) {
                    sendBroadcast(new Intent(Mode.PLAYING));
                    addProgressListener();
                } else {
                    sendBroadcast(new Intent(Mode.READY));
                }
                break;
            case ExoPlayer.STATE_ENDED:
                if (this.player != null) {
                    sendBroadcast(new Intent(Mode.STOPPED));
                }
                break;
        }
        Log.d("onPlayerStateChanged", "" + playbackState + ":" + (this.player != null ? this.player.getPlaybackState() : 0));
    }

    @Override
    public void onTimelineChanged(Timeline timeline, Object manifest) {
    }


    @Override
    public void onPlayerError(ExoPlaybackException error) {
        Log.d("onPlayerError", "" + error.getMessage());
        if(!isConnected()) {
            Log.d("isConnected", isConnected() ? "true" : "false");
        }
        sendBroadcast(new Intent(Mode.ERROR));
    }

    @Override
    public void onPositionDiscontinuity() {

    }

    private void addProgressListener() {
        mHandler.postDelayed(mProgressTickRunnable, 0);
    }

    private void removeProgressListener() {
        mHandler.removeCallbacks(mProgressTickRunnable);
    }

    /**
     * Player controls
     */

    public void play(String url) {
        if ( player != null ) {
            player.setPlayWhenReady(false);
            player.stop();
            player.seekTo(0);
        }

        this.streamingURL = url;

        boolean playWhenReady = true; // TODO Allow user to customize this

        // Create player
        TrackSelector trackSelector = new DefaultTrackSelector();
        player = ExoPlayerFactory.newSimpleInstance(this.getApplicationContext(), trackSelector);
        player.addListener(this);

        // Start listening to audio focus
        AudioManager am = (AudioManager) context.getSystemService(Context.AUDIO_SERVICE);
        assert am != null;
        am.requestAudioFocus(afChangeListener, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN);

        prepare(true);
    }

    private void prepare(boolean playWhenReady) {

        Handler mainHandler = new Handler();
        String userAgent = Util.getUserAgent(this, "RNAudioStreaming");

        // Create source
        ExtractorsFactory extractorsFactory = new DefaultExtractorsFactory();
        DefaultBandwidthMeter bandwidthMeter = new DefaultBandwidthMeter();
        DataSource.Factory dataSourceFactory = new DefaultDataSourceFactory(this.getApplication(), userAgent, bandwidthMeter);
        MediaSource audioSource = new ExtractorMediaSource(Uri.parse(this.streamingURL), dataSourceFactory, extractorsFactory, mainHandler, this);

        // Start preparing audio
        player.prepare(audioSource, false, false);
        player.setPlayWhenReady(playWhenReady);
    }

    public void start() {
        if ( player != null ) {
            player.setPlayWhenReady(true);
        }
    }

    public void pause() {
        if ( player != null ) {
            player.setPlayWhenReady(false);
        }
    }

    public void resume() {
        if ( player != null ) {
            prepare(true);
            player.setPlayWhenReady(true);
        }
    }

    public void stop() {
        if ( player != null ) {
            player.setPlayWhenReady(false);
        }
    }

    public boolean isPlaying() {
        return player != null && player.getPlayWhenReady() && player.getPlaybackState() != ExoPlayer.STATE_ENDED;
    }

    public long getDuration() {
        return player != null ? player.getDuration() : 0L;
    }

    public long getCurrentPosition() {
        return player != null ? player.getCurrentPosition() : 0L;
    }

    public int getBufferPercentage() {
        return player.getBufferedPercentage();
    }

    public void seekTo(long timeMillis) {
        if ( player != null ) {
            player.seekTo(timeMillis);
        }
    }

    public void goForward(double seconds) {
        if ( player != null ) {
            long progress = getCurrentPosition();
            long duration = getDuration();
            long newTime = (long) (progress + (seconds * 1000));

            if ( duration < newTime ) {
                stop();
            } else {
                seekTo(newTime);
            }
        }
    }

    public void goBack(double seconds) {
        if ( player != null ) {
            long progress = getCurrentPosition();
            long duration = getDuration();
            long newTime = (long) (progress - (seconds * 1000));

            if ( newTime < 0 ) {
                seekTo(0);
            } else {
                seekTo(newTime);
            }
        }
    }

    private boolean isConnected() {
        ConnectivityManager cm = (ConnectivityManager) getSystemService(Context.CONNECTIVITY_SERVICE);
        NetworkInfo netInfo = cm != null ? cm.getActiveNetworkInfo() : null;
        return netInfo != null && netInfo.isConnectedOrConnecting();
    }

    public void setPlaybackRate(float speed) {
        if ( player != null ) {
            PlaybackParameters pp = new PlaybackParameters(speed, 1);
            player.setPlaybackParameters(pp);
        }
    }

    /**
     * Meta data information
     */

    @Override
    public void onMetadata(Metadata metadata) {

    }

    /**
     * Notification control
     */

    @Override
    public IBinder onBind(Intent intent) {
        return binder;
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        return Service.START_NOT_STICKY;
    }

    // Notification
    private PendingIntent makePendingIntent(String broadcast) {
        Intent intent = new Intent(broadcast);
        return PendingIntent.getBroadcast(this.context, 0, intent, 0);
    }

    public class RadioBinder extends Binder {
        public Signal getService() {
            return Signal.this;
        }
    }

    public String getStreamingURL() {
        return this.streamingURL;
    }

    @Override
    public void onLoadError(IOException error) {
        Log.e(TAG, error.getMessage());
    }

}
