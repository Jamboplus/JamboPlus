package com.jamboplus.orizon

import android.content.Context
import android.graphics.Color
import android.os.Message
import android.view.ViewGroup
import android.webkit.CookieManager
import android.webkit.WebChromeClient
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.FrameLayout

/** WebView settings tuned for PHP gateways and Google reCAPTCHA challenges. */
object GatewayWebViewHelper {

    /** Chrome-like UA without the WebView `; wv` token — reCAPTCHA often blocks WebView UAs. */
    fun browserUserAgent(context: Context): String {
        val default = WebSettings.getDefaultUserAgent(context)
        return when {
            default.contains("; wv") -> default.replace("; wv", "")
            default.contains(" wv ") -> default.replace(" wv ", " ")
            else -> default
        }
    }

    fun applySettings(webView: WebView, context: Context, userAgent: String? = null) {
        webView.setBackgroundColor(Color.BLACK)
        webView.settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            databaseEnabled = true
            allowFileAccess = true
            allowContentAccess = true
            allowFileAccessFromFileURLs = true
            allowUniversalAccessFromFileURLs = true
            mediaPlaybackRequiresUserGesture = false
            mixedContentMode = WebSettings.MIXED_CONTENT_ALWAYS_ALLOW
            setSupportMultipleWindows(true)
            javaScriptCanOpenWindowsAutomatically = true
            loadWithOverviewMode = true
            useWideViewPort = true
            loadsImagesAutomatically = true
            blockNetworkImage = false
            cacheMode = WebSettings.LOAD_DEFAULT
            setSupportZoom(true)
            builtInZoomControls = false
            displayZoomControls = false
            userAgentString = userAgent?.takeIf { it.isNotBlank() } ?: browserUserAgent(context)
        }
        CookieManager.getInstance().setAcceptCookie(true)
        CookieManager.getInstance().setAcceptThirdPartyCookies(webView, true)
    }

    /**
     * Handles reCAPTCHA popups (`window.open`) by hosting a child WebView over the player container.
     */
    fun createChromeClient(
        hostWebView: WebView,
        onConsoleMessage: ((android.webkit.ConsoleMessage?) -> Unit)? = null,
    ): WebChromeClient {
        return object : WebChromeClient() {
            override fun onCreateWindow(
                view: WebView,
                isDialog: Boolean,
                isUserGesture: Boolean,
                resultMsg: Message,
            ): Boolean {
                val popup = WebView(view.context)
                applySettings(popup, view.context, view.settings.userAgentString)
                popup.webViewClient = object : WebViewClient() {
                    override fun shouldOverrideUrlLoading(
                        w: WebView,
                        request: android.webkit.WebResourceRequest,
                    ): Boolean = false
                }
                popup.webChromeClient = object : WebChromeClient() {
                    override fun onCloseWindow(window: WebView) {
                        dismissPopup(window)
                    }
                }
                val parent = view.parent as? ViewGroup
                    ?: (hostWebView.parent as? ViewGroup)
                    ?: return false
                parent.addView(
                    popup,
                    FrameLayout.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT,
                        ViewGroup.LayoutParams.MATCH_PARENT,
                    ),
                )
                val transport = resultMsg.obj as? WebView.WebViewTransport ?: return false
                transport.webView = popup
                resultMsg.sendToTarget()
                return true
            }

            override fun onCloseWindow(window: WebView) {
                dismissPopup(window)
            }

            override fun onPermissionRequest(request: android.webkit.PermissionRequest?) {
                request?.grant(request.resources)
            }

            override fun onConsoleMessage(
                consoleMessage: android.webkit.ConsoleMessage?,
            ): Boolean {
                onConsoleMessage?.invoke(consoleMessage)
                return true
            }
        }
    }

    private fun dismissPopup(window: WebView) {
        (window.parent as? ViewGroup)?.removeView(window)
        window.stopLoading()
        window.destroy()
    }

    /**
     * WebView EME/MediaCapabilities compat for embed pages that ship their own Shaka.
     * Azam-style MPDs list PlayReady before Widevine; Android only has Widevine L3,
     * so we remap PlayReady→Widevine and force SW_SECURE_CRYPTO (same as Washa).
     */
    const val EME_L3_COMPAT_JS = """
        (function(){
          var WV = 'com.widevine.alpha';
          var L3 = 'SW_SECURE_CRYPTO';
          function isPlayReady(ks) {
            return String(ks || '').toLowerCase().indexOf('playready') >= 0;
          }
          function isFairPlay(ks) {
            var s = String(ks || '').toLowerCase();
            return s.indexOf('fairplay') >= 0 || s.indexOf('com.apple.fps') >= 0;
          }
          function mapKeySystem(ks) {
            if (isPlayReady(ks) || isFairPlay(ks)) return WV;
            return ks;
          }
          function softenCap(cap) {
            if (!cap || typeof cap !== 'object') return cap;
            var c = {};
            for (var k in cap) {
              if (Object.prototype.hasOwnProperty.call(cap, k) && k !== 'encryptionScheme') c[k] = cap[k];
            }
            var r = String(c.robustness || '');
            if (!r || r.indexOf('HW_') === 0 || r.indexOf('SW_SECURE_DECODE') === 0) {
              c.robustness = L3;
            }
            return c;
          }
          function softenConfig(cfg) {
            if (!cfg || typeof cfg !== 'object') return cfg;
            var c = {};
            for (var k in cfg) if (Object.prototype.hasOwnProperty.call(cfg, k)) c[k] = cfg[k];
            if (c.videoCapabilities) c.videoCapabilities = [].map.call(c.videoCapabilities, softenCap);
            if (c.audioCapabilities) c.audioCapabilities = [].map.call(c.audioCapabilities, softenCap);
            if (c.persistentState === 'required') c.persistentState = 'optional';
            if (c.distinctiveIdentifier === 'required') c.distinctiveIdentifier = 'optional';
            if (c.sessionTypes && c.sessionTypes.length && c.sessionTypes.indexOf('temporary') < 0) {
              c.sessionTypes = ['temporary'];
            }
            return c;
          }
          function softenMcKeySystemConfig(ksc) {
            if (!ksc || typeof ksc !== 'object') return ksc;
            var c = {};
            for (var k in ksc) if (Object.prototype.hasOwnProperty.call(ksc, k)) c[k] = ksc[k];
            c.keySystem = mapKeySystem(c.keySystem || WV);
            if (c.video) {
              c.video = softenCap(c.video);
              if (c.video && 'encryptionScheme' in c.video) delete c.video.encryptionScheme;
            }
            if (c.audio) {
              c.audio = softenCap(c.audio);
              if (c.audio && 'encryptionScheme' in c.audio) delete c.audio.encryptionScheme;
            }
            if (!c.video && !c.audio) {
              c.video = { contentType: 'video/mp4; codecs="avc1.42E01E"', robustness: L3 };
              c.audio = { contentType: 'audio/mp4; codecs="mp4a.40.2"', robustness: L3 };
            }
            if (c.persistentState === 'required') c.persistentState = 'optional';
            if (c.distinctiveIdentifier === 'required') c.distinctiveIdentifier = 'optional';
            return c;
          }
          function l3FallbackConfigs() {
            return [{
              initDataTypes: ['cenc', 'keyids', 'webm'],
              distinctiveIdentifier: 'optional',
              persistentState: 'optional',
              sessionTypes: ['temporary'],
              videoCapabilities: [
                {contentType: 'video/mp4; codecs="avc1.42E01E"', robustness: L3},
                {contentType: 'video/mp4; codecs="avc1.4d401e"', robustness: L3},
                {contentType: 'video/mp4; codecs="avc1.64001e"', robustness: L3},
                {contentType: 'video/mp4; codecs="avc1.64001f"', robustness: L3},
                {contentType: 'video/mp4; codecs="avc1.640028"', robustness: L3}
              ],
              audioCapabilities: [
                {contentType: 'audio/mp4; codecs="mp4a.40.2"', robustness: L3}
              ]
            }];
          }
          function installEmeWrap() {
            var cur = navigator.requestMediaKeySystemAccess;
            if (!cur || cur.__jamboWrapped) return;
            var orig = cur.bind(navigator);
            var wrapped = function(keySystem, configs) {
              var mapped = mapKeySystem(keySystem);
              var next = configs;
              try { next = [].map.call(configs || [], softenConfig); } catch (e) {}
              if (!next || !next.length) next = l3FallbackConfigs();
              return orig(mapped, next).catch(function(err) {
                return orig(WV, l3FallbackConfigs());
              });
            };
            wrapped.__jamboWrapped = true;
            navigator.requestMediaKeySystemAccess = wrapped;
          }
          function installMcWrap() {
            try {
              if (!navigator.mediaCapabilities || !navigator.mediaCapabilities.decodingInfo) return;
              var mc = navigator.mediaCapabilities;
              if (mc.decodingInfo.__jamboWrapped) return;
              var origDi = mc.decodingInfo.bind(mc);
              var wrappedDi = function(config) {
                var cfg = config;
                try {
                  if (config && typeof config === 'object') {
                    cfg = {};
                    for (var k in config) if (Object.prototype.hasOwnProperty.call(config, k)) cfg[k] = config[k];
                    if (cfg.keySystemConfiguration) {
                      cfg.keySystemConfiguration = softenMcKeySystemConfig(cfg.keySystemConfiguration);
                    }
                  }
                } catch (e) {}
                return origDi(cfg).then(function(result) {
                  try {
                    if (result && result.supported === false && cfg && cfg.keySystemConfiguration) {
                      var retry = {};
                      for (var k2 in cfg) if (Object.prototype.hasOwnProperty.call(cfg, k2)) retry[k2] = cfg[k2];
                      retry.keySystemConfiguration = softenMcKeySystemConfig({
                        keySystem: WV,
                        initDataType: (cfg.keySystemConfiguration && cfg.keySystemConfiguration.initDataType) || 'cenc',
                        video: { contentType: 'video/mp4; codecs="avc1.42E01E"', robustness: L3 },
                        audio: { contentType: 'audio/mp4; codecs="mp4a.40.2"', robustness: L3 },
                        distinctiveIdentifier: 'optional',
                        persistentState: 'optional',
                        sessionType: 'temporary'
                      });
                      return origDi(retry);
                    }
                  } catch (e2) {}
                  return result;
                });
              };
              wrappedDi.__jamboWrapped = true;
              mc.decodingInfo = wrappedDi;
            } catch (e) {}
          }
          var _origConfigure = null;
          function preferWidevineOn(player) {
            try {
              if (!player || player.__jamboDrmPreferred) return;
              player.__jamboDrmPreferred = true;
              var fn = _origConfigure || player.configure;
              if (typeof fn !== 'function') return;
              fn.call(player, {
                drm: {
                  preferredKeySystems: [WV],
                  keySystemsMapping: {
                    'com.microsoft.playready': WV,
                    'com.microsoft.playready.recommendation': WV
                  },
                  advanced: {
                    'com.widevine.alpha': {
                      videoRobustness: L3,
                      audioRobustness: L3,
                      persistentStateRequired: false,
                      distinctiveIdentifierRequired: false
                    }
                  }
                }
              });
            } catch (e) {
              try { player.__jamboDrmPreferred = false; } catch (e2) {}
            }
          }
          function hookShaka() {
            try {
              if (!window.shaka || !window.shaka.Player) return false;
              installEmeWrap();
              installMcWrap();
              if (window.__jamboShakaHook) return true;
              window.__jamboShakaHook = true;
              var Proto = window.shaka.Player.prototype;
              _origConfigure = Proto.configure;
              var attach = Proto.attach;
              var load = Proto.load;
              if (typeof _origConfigure === 'function') {
                Proto.configure = function() {
                  var ret = _origConfigure.apply(this, arguments);
                  this.__jamboDrmPreferred = false;
                  preferWidevineOn(this);
                  return ret;
                };
              }
              if (typeof attach === 'function') {
                Proto.attach = function() {
                  preferWidevineOn(this);
                  return attach.apply(this, arguments);
                };
              }
              if (typeof load === 'function') {
                Proto.load = function() {
                  installEmeWrap();
                  installMcWrap();
                  this.__jamboDrmPreferred = false;
                  preferWidevineOn(this);
                  return load.apply(this, arguments);
                };
              }
              return true;
            } catch (e) { return false; }
          }
          installEmeWrap();
          installMcWrap();
          hookShaka();
          if (!window.__jamboEmeTimer) {
            var tries = 0;
            window.__jamboEmeTimer = setInterval(function() {
              tries++;
              installEmeWrap();
              installMcWrap();
              hookShaka();
              if (tries > 60) {
                clearInterval(window.__jamboEmeTimer);
                window.__jamboEmeTimer = null;
              }
            }, 200);
          }
        })();
    """

    /** Returns `video` when a player element exists, `captcha` while reCAPTCHA is on screen. */
    const val PAGE_PROBE_JS = """
        (function(){
          try{
            if(document.querySelector('video')) return 'video';
            if(document.querySelector('iframe[src*="recaptcha"], iframe[src*="google.com/recaptcha"], .g-recaptcha, [data-sitekey]')) return 'captcha';
          }catch(e){}
          return 'waiting';
        })();
    """
}
