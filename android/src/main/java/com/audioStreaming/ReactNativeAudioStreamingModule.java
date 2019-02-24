package com.audioStreaming;

import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.ServiceConnection;
import android.os.IBinder;
import android.util.Log;
import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.Callback;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.bridge.Promise;
import com.facebook.react.modules.core.DeviceEventManagerModule;
import javax.annotation.Nullable;
import android.app.Activity;

class ReactNativeAudioStreamingModule extends ReactContextBaseJavaModule implements ServiceConnection {

  public static final String SHOULD_SHOW_NOTIFICATION = "showInAndroidNotifications";
  private static final String ERROR = "REACT_NATIVE_AUDIO_STREAMING_ERROR";
  private final ReactApplicationContext context;

  private Class<?> clsActivity;
  private static Signal signal;
  private boolean shouldShowNotification;


  public ReactNativeAudioStreamingModule(ReactApplicationContext reactContext) {
    super(reactContext);
    this.context = reactContext;
  }

  public ReactApplicationContext getReactApplicationContextModule() {
    return this.context;
  }

  public Class<?> getClassActivity() {
    Activity activity = getCurrentActivity();
    if (this.clsActivity == null && activity != null) {
      this.clsActivity = activity.getClass();
    }
    return this.clsActivity;
  }

  public void stopOncall() {
    signal.stop();
  }

  public Signal getSignal() {
    return signal;
  }

  public void sendEvent(ReactContext reactContext, String eventName, @Nullable WritableMap params) {
    this.context.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class).emit(eventName, params);
  }

  @Override
  public String getName() {
    return "ReactNativeAudioStreaming";
  }

  @Override
  public void initialize() {
    super.initialize();

    try {
      Intent bindIntent = new Intent(this.context, Signal.class);
      this.context.bindService(bindIntent, this, Context.BIND_AUTO_CREATE);
    } catch (Exception e) {
      Log.e("ERROR", e.getMessage());
    }
  }

  @Override
  public void onServiceConnected(ComponentName className, IBinder service) {
    signal = ((Signal.RadioBinder) service).getService();
    signal.setData(this.context, this);
    WritableMap params = Arguments.createMap();
    sendEvent(this.getReactApplicationContextModule(), "streamingOpen", params);
  }

  @Override
  public void onServiceDisconnected(ComponentName className) {
    signal = null;
  }

  @ReactMethod
  public void play(String streamingURL, int seconds, final Promise promise) {
    try {
      long timeMillis = seconds * 1000;
      signal.play(streamingURL, timeMillis);
    } catch (Exception e) {
      promise.reject(ERROR, e);
    }
  }

  @ReactMethod
  private void stop(final Promise promise) {
    try {
      signal.stop();
      promise.resolve(true);
    } catch (Exception e) {
      promise.reject(ERROR, e);
    }
  }

  @ReactMethod
  public void pause(final Promise promise) {
    try {
      signal.pause();
      promise.resolve(true);
    } catch (Exception e) {
      promise.reject(ERROR, e);
    }
  }

  @ReactMethod
  public void resume(final Promise promise) {
    try {
      signal.resume();
      promise.resolve(true);
    } catch (Exception e) {
      promise.reject(ERROR, e);
    }
  }

  @ReactMethod
  public void seekToTime(int seconds, final Promise promise) {
    try {
      signal.seekTo(seconds * 1000);
      promise.resolve(true);
    } catch (Exception e) {
      promise.reject(ERROR, e);
    }
  }

  @ReactMethod
  public void goForward(double seconds, final Promise promise) {
    try {
      signal.goForward(seconds);
      promise.resolve(true);
    } catch (Exception e) {
      promise.reject(ERROR, e);
    }
  }

  @ReactMethod
  public void goBack(double seconds, final Promise promise) {
    try {
      signal.goBack(seconds);
      promise.resolve(true);
    } catch (Exception e) {
      promise.reject(ERROR, e);
    }
  }

  @ReactMethod
  public void setPlaybackRate(float speed, final Promise promise) {
    try {
      signal.setPlaybackRate(speed);
      promise.resolve(true);
    } catch (Exception e) {
      promise.reject(ERROR, e);
    }
  }

  @ReactMethod
  public void getStatus(Callback callback) {
    WritableMap state = Arguments.createMap();
    state.putDouble("duration", signal.getDuration());
    state.putDouble("progress", signal.getCurrentPosition());
    state.putString("status", signal != null && signal.isPlaying() ? Mode.PLAYING : Mode.STOPPED);
    state.putString("url", signal.getStreamingURL());
    callback.invoke(null, state);
  }
}
