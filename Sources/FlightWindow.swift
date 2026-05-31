import Cocoa
import WebKit

class FlightTracker {
    var startTime = Date()
    var isDismissing = false
    var dismissStartTime = Date()
    var dismissStartX: CGFloat = 0.0
    
    var duration: TimeInterval = 16.0
    var dismissDuration: TimeInterval = 1.5
    
    var startX: CGFloat = 0
    var endX: CGFloat = 0
    var groupWidth: CGFloat = 850
    var mode: Int = 0
    
    func getCurrentX(screenWidth: CGFloat) -> CGFloat {
        let now = Date()
        self.startX = -groupWidth
        self.endX = screenWidth
        
        if isDismissing {
            let elapsed = now.timeIntervalSince(dismissStartTime)
            let p = min(elapsed / dismissDuration, 1.0)
            let easeInP = p * p
            return dismissStartX + (endX - dismissStartX) * CGFloat(easeInP)
        } else {
            let elapsed = now.timeIntervalSince(startTime)
            let progress = min(elapsed / duration, 1.0)
            
            if mode == 0 {
                return startX + (endX - startX) * CGFloat(progress)
            } else {
                let targetProgress: Double = 0.5
                if progress < targetProgress {
                    let entranceProgress = progress / targetProgress
                    return startX + (endX / 2 - startX) * CGFloat(entranceProgress)
                } else {
                    return endX / 2
                }
            }
        }
    }
}

class FlightScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var window: FlightWindow?
    var onFinished: () -> Void
    
    init(window: FlightWindow?, onFinished: @escaping () -> Void) {
        self.window = window
        self.onFinished = onFinished
        super.init()
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? String else { return }
        
        if body == "startDismiss" {
            DispatchQueue.main.async { [weak self] in
                self?.window?.startDismissTracker()
            }
        } else if body == "finished" {
            DispatchQueue.main.async { [weak self] in
                self?.window?.close()
                self?.onFinished()
            }
        }
    }
}

class FlightWebView: WKWebView {
    let tracker: FlightTracker
    
    init(frame: CGRect, configuration: WKWebViewConfiguration, tracker: FlightTracker) {
        self.tracker = tracker
        super.init(frame: frame, configuration: configuration)
        self.setValue(false, forKey: "drawsBackground") // Transparent background
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        let screenHeight = self.bounds.height
        let currentX = tracker.getCurrentX(screenWidth: self.bounds.width)
        
        let groupWidth: CGFloat = 850
        let groupHeight: CGFloat = 360
        let boxY = (screenHeight - groupHeight) / 2
        
        let appKitFrame = NSRect(
            x: currentX,
            y: boxY,
            width: groupWidth,
            height: groupHeight
        )
        
        if appKitFrame.contains(point) {
            return super.hitTest(point)
        }
        return nil
    }
}

class FlightWindow: NSPanel {
    private var webView: FlightWebView?
    private let tracker = FlightTracker()
    
    init(reminderText: String, isImportant: Bool, style: Int, mode: Int, onFinished: @escaping () -> Void) {
        let screenRect = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        
        super.init(
            contentRect: screenRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .statusBar
        self.ignoresMouseEvents = (mode == 0)
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.hasShadow = false
        
        tracker.mode = mode
        
        // Setup message handler
        let contentController = WKUserContentController()
        let handler = FlightScriptMessageHandler(window: self, onFinished: onFinished)
        contentController.add(handler, name: "dismiss")
        
        let config = WKWebViewConfiguration()
        config.userContentController = contentController
        
        let webView = FlightWebView(frame: NSRect(origin: .zero, size: screenRect.size), configuration: config, tracker: tracker)
        self.webView = webView
        self.contentView = webView
        
        // Build the HTML template
        let escapedText = reminderText
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
        
        let htmlTemplate = getHTMLTemplate()
        let planeBase64 = AirplaneAsset.getBase64Image(for: 0)
        let processedHtml = htmlTemplate
            .replacingOccurrences(of: "##TEXT##", with: escapedText)
            .replacingOccurrences(of: "##IMPORTANT##", with: isImportant ? "true" : "false")
            .replacingOccurrences(of: "##MODE##", with: "\(mode)")
            .replacingOccurrences(of: "##PLANE_BASE64##", with: planeBase64)
        
        webView.loadHTMLString(processedHtml, baseURL: nil)
    }
    
    override var canBecomeKey: Bool {
        return false
    }
    
    override var canBecomeMain: Bool {
        return false
    }
    
    func dismiss() {
        webView?.evaluateJavaScript("dismissFlight()", completionHandler: nil)
    }
    
    func startDismissTracker() {
        tracker.dismissStartX = tracker.getCurrentX(screenWidth: self.frame.width)
        tracker.isDismissing = true
        tracker.dismissStartTime = Date()
    }
    
    private func getHTMLTemplate() -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
          body, html {
            margin: 0;
            padding: 0;
            width: 100%;
            height: 100%;
            overflow: hidden;
            background-color: transparent;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
          }
          
          #container {
            position: relative;
            width: 100%;
            height: 100%;
            background-color: transparent;
            z-index: 0;
          }
          
          #flight-group {
            position: absolute;
            display: flex;
            align-items: center;
            height: 250px;
            top: calc(50% - 125px);
            left: 0;
            transform: translate3d(-900px, 0, 0);
            will-change: transform;
            pointer-events: auto;
            cursor: pointer;
            z-index: 10;
          }
          
          .banner-container {
            width: 520px;
            height: 100px;
            background: rgba(255, 255, 255, 0.94);
            border: 3px solid #ff4500;
            border-radius: 22px;
            box-shadow: 0 12px 30px rgba(0,0,0,0.18);
            display: flex;
            align-items: center;
            padding: 0 30px;
            box-sizing: border-box;
            backdrop-filter: blur(12px);
            transform-origin: right center;
          }
          
          .banner-content {
            display: flex;
            align-items: center;
            gap: 16px;
            width: 100%;
          }
          
          .bell-icon {
            font-size: 26px;
            animation: ring 2.0s ease-in-out infinite;
          }
          
          @keyframes ring {
            0%, 100% { transform: rotate(0); }
            10% { transform: rotate(18deg); }
            20% { transform: rotate(-12deg); }
            30% { transform: rotate(10deg); }
            40% { transform: rotate(-8deg); }
            50% { transform: rotate(0); }
          }
          
          .banner-text {
            font-size: 18px;
            font-weight: bold;
            color: #111;
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
            font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", sans-serif;
            -webkit-font-smoothing: antialiased;
            -moz-osx-font-smoothing: grayscale;
            text-rendering: optimizeLegibility;
          }
          
          .ropes-svg {
            width: 40px;
            height: 80px;
          }
          
          .airplane-wrapper {
            position: relative;
            width: 290px;
            height: 160px;
          }
          
          .escort-plane {
            position: absolute;
            width: 200px;
            height: 115px;
            opacity: 0.95;
          }
          .escort-upper {
            left: -70px;
            top: -95px;
          }
          .escort-lower {
            left: -70px;
            top: 95px;
          }
          
          .propeller-overlay {
            position: absolute;
            right: 0px;
            top: 30px; /* Center of plane's nose hub (160/2 - 100/2) */
            width: 22px;
            height: 100px;
            pointer-events: none;
          }
          
          .propeller {
            transform-origin: 11px 50px;
            animation: spinPropeller 0.12s linear infinite;
          }
          
          @keyframes spinPropeller {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
          }
        </style>
        </head>
        <body>
          <div id="container">
            <div id="flight-group" onclick="dismissFlight()">
              <!-- Banner -->
              <div class="banner-container">
                <div class="banner-content">
                  <div class="bell-icon">🔔</div>
                  <div class="banner-text" id="text-node">提醒内容</div>
                </div>
              </div>
              
              <!-- Ropes -->
              <svg class="ropes-svg" viewBox="0 0 40 80">
                <path d="M 0 20 Q 20 25 40 20" stroke="#444" stroke-width="2.5" stroke-dasharray="3,2" fill="none"/>
                <path d="M 0 60 Q 20 55 40 60" stroke="#444" stroke-width="2.5" stroke-dasharray="3,2" fill="none"/>
              </svg>
              
              <!-- Lead Airplane & Escorts -->
              <div class="airplane-wrapper" id="planes-container">
                <!-- 3D Claymation Plane Image -->
                <img id="lead-plane" src="data:image/png;base64,##PLANE_BASE64##" width="290" height="160" />
                
                <!-- Propeller overlay -->
                <div class="propeller-overlay">
                  <svg class="propeller" viewBox="0 0 22 100" width="22" height="100">
                    <ellipse cx="11" cy="50" rx="3.8" ry="46" fill="rgba(240, 240, 240, 0.7)" stroke="rgba(200, 200, 200, 0.4)" stroke-width="0.5"/>
                    <ellipse cx="11" cy="50" rx="46" ry="3.8" fill="rgba(240, 240, 240, 0.2)"/>
                    <circle cx="11" cy="50" r="5" fill="#ff4500"/>
                    <circle cx="11" cy="50" r="2" fill="#333"/>
                  </svg>
                </div>
              </div>
            </div>
          </div>

          <script>
            var reminderText = "##TEXT##";
            var isImportant = ##IMPORTANT##;
            var mode = ##MODE##;
            
            document.getElementById("text-node").innerText = reminderText;
            
            if (isImportant) {
              var container = document.getElementById("planes-container");
              
              var upper = document.createElement("div");
              upper.className = "escort-plane escort-upper";
              upper.innerHTML = getPlaneSVG();
              container.appendChild(upper);
              
              var lower = document.createElement("div");
              lower.className = "escort-plane escort-lower";
              lower.innerHTML = getPlaneSVG();
              container.appendChild(lower);
            }
            
            function getPlaneSVG() {
              return `<div style="position:relative; width:100%; height:100%;">
                <img src="data:image/png;base64,##PLANE_BASE64##" width="200" height="115" />
                <div class="propeller-overlay" style="top: 22px; right: 0px; width: 18px; height: 70px;">
                  <svg class="propeller" viewBox="0 0 18 70" width="18" height="70" style="transform-origin: 9px 35px;">
                    <ellipse cx="9" cy="35" rx="2.8" ry="32" fill="rgba(240, 240, 240, 0.7)" stroke="rgba(200, 200, 200, 0.4)" stroke-width="0.5"/>
                    <ellipse cx="9" cy="35" rx="32" ry="2.8" fill="rgba(240, 240, 240, 0.2)"/>
                    <circle cx="9" cy="35" r="4" fill="#ff4500"/>
                    <circle cx="9" cy="35" r="1.5" fill="#333"/>
                  </svg>
                </div>
              </div>`;
            }
            
            var flightGroup = document.getElementById("flight-group");
            var groupWidth = 850;
            var startX = -groupWidth;
            var endX = window.innerWidth;
            var currentX = startX;
            
            var startTime = Date.now();
            var duration = 16000;
            var isDismissing = false;
            var dismissStartTime = 0;
            
            function animate() {
              var now = Date.now();
              
              if (isDismissing) {
                var elapsed = now - dismissStartTime;
                var p = Math.min(elapsed / 1500, 1.0);
                var easeInP = p * p; 
                currentX = dismissStartX + (endX - dismissStartX) * easeInP;
                
                if (p >= 1.0) {
                  window.webkit.messageHandlers.dismiss.postMessage("finished");
                  return;
                }
              } else {
                var elapsed = now - startTime;
                var progress = Math.min(elapsed / duration, 1.0);
                
                if (mode === 0) {
                  currentX = startX + (endX - startX) * progress;
                  if (progress >= 1.0) {
                    window.webkit.messageHandlers.dismiss.postMessage("finished");
                    return;
                  }
                } else if (mode === 1) {
                  var targetProgress = 0.5;
                  if (progress < targetProgress) {
                    var entranceProgress = progress / targetProgress;
                    currentX = startX + (endX / 2 - startX) * entranceProgress;
                  } else {
                    currentX = endX / 2;
                  }
                }
              }
              
              flightGroup.style.transform = "translate3d(" + Math.round(currentX) + "px, 0, 0)";
              requestAnimationFrame(animate);
            }
            
            var dismissStartX = 0;
            
            function dismissFlight() {
              if (isDismissing) return;
              
              dismissStartX = currentX;
              isDismissing = true;
              dismissStartTime = Date.now();
              
              window.webkit.messageHandlers.dismiss.postMessage("startDismiss");
            }
            
            requestAnimationFrame(animate);
          </script>
        </body>
        </html>
        """
    }
}
