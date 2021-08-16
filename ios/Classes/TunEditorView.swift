import Flutter
import UIKit
import SwiftUI
import WebKit

class TunEditorViewFactory: NSObject, FlutterPlatformViewFactory {

    private var messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        return TunEditorView(
            frame: frame,
            viewIdentifier: viewId,
            arguments: args,
            binaryMessenger: messenger)
    }
    
    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }

}

class TunEditorView: NSObject, FlutterPlatformView {

    private var _editor: QuillEditorView
    
    private var methodChannel: FlutterMethodChannel

    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        binaryMessenger messenger: FlutterBinaryMessenger
    ) {
        let configuration = WKWebViewConfiguration()
        
        var placeholder: String = ""
        var padding: [Int] = [12, 15, 12, 15]
        var readOnly: Bool = false
        var autoFocus: Bool = false
        var delta: [Any] = []
        
        if let argsMap = args as? [String: Any] {
            if let optPlaceholder = argsMap["placeholder"] as? String {
                placeholder = optPlaceholder
            }
            if let optPadding = argsMap["padding"] as? [Int] {
                padding = optPadding
            }
            if let optReadOnly = argsMap["readOnly"] as? Bool {
                readOnly = optReadOnly
            }
            if let optAutoFocus = argsMap["autoFocus"] as? Bool {
                autoFocus = optAutoFocus
            }
            if let optDelta = argsMap["delta"] as? [Any] {
                delta = optDelta
            }
        }
        _editor = QuillEditorView(
            frame: frame,
            configuration: configuration,
            placeholder: placeholder,
            padding: padding,
            readOnly: readOnly,
            autoFocus: autoFocus,
            delta: delta
        )
        methodChannel = FlutterMethodChannel(name: "tun/editor/\(viewId)", binaryMessenger: messenger)
        super.init()

        _editor.frame = frame
        _editor.setOnTextChangeListener { args in
            self.methodChannel.invokeMethod("onTextChange", arguments: args)
        }
        _editor.setOnSelectionChangeListener { args in
            self.methodChannel.invokeMethod("onSelectionChange", arguments: args)
        }
        _editor.setOnMentionClickListener { args in
            print("on mention click \(args)")
            self.methodChannel.invokeMethod("onMentionClick", arguments: args)
        }
        _editor.setOnLinkClickListener { args in
            print("on link click \(args)")
            if let url = args["url"] as? String {
                self.methodChannel.invokeMethod("onLinkClick", arguments: url)
            }
        }
        _editor.setOnFocusChangeListener { args in
            print("on focus change \(args)")
            if let hasFocus = args["hasFocus"] as? Bool {
                self.methodChannel.invokeMethod("onFocusChange", arguments: hasFocus)
            }
        }
        methodChannel.setMethodCallHandler(handle)
    }

    func view() -> UIView {
        return _editor
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        debugPrint("handle method in tun editor: \(call.method)")
        switch call.method {
        // Content related.
        case "replaceText":
            if let args = call.arguments as? [String: Any] {
                let index = args["index"] as? Int
                let length = args["length"] as? Int
                let data = args["data"]
                if index == nil || length == nil || data == nil {
                    return
                }
                _editor.replaceText(index: index!, length: length!, data: data!)
            }
        case "insertMention":
            if let args = call.arguments as? [String: Any] {
                let id = args["id"] as? String
                let text = args["text"] as? String
                if id == nil || text == nil {
                    return
                }
                _editor.insertMention(id: id!, text: text!)
            }
        case "insertDivider":
            _editor.insertDivider()
        case "insertImage":
            if let url = call.arguments as? String {
                _editor.insertImage(url)
            }
        case "insertLink":
            if let args = call.arguments as? [String: Any] {
                let text = args["text"] as? String
                let url = args["url"] as? String
                if text == nil || url == nil {
                    return
                }
                _editor.insertLink(text!, url!)
            }

        // Format related.
        case "setTextType":
            let textType: String = call.arguments is String
                ? call.arguments as! String
                : TextType.normal.rawValue
            switch textType {
            case TextType.normal.rawValue:
                _editor.format(name: "header", value: false)
                _editor.format(name: "list", value: false)
                _editor.format(name: "blockquote", value: false)
                _editor.format(name: "code-block", value: false)
            case TextType.headline1.rawValue:
                _editor.format(name: "header", value: 1)
            case TextType.headline2.rawValue:
                _editor.format(name: "header", value: 2)
            case TextType.headline3.rawValue:
                _editor.format(name: "header", value: 3)
            case TextType.listBullet.rawValue:
                _editor.format(name: "list", value: "bullet")
            case TextType.listOrdered.rawValue:
                _editor.format(name: "list", value: "ordered")
            case TextType.quote.rawValue:
                _editor.format(name: "blockquote", value: true)
            case TextType.codeBlock.rawValue:
                _editor.format(name: "code-block", value: true)
            default:
                print("missing text type")
            }
        case "setTextStyle":
            if let styles = call.arguments as? [String] {
                _editor.format(name: "bold", value: styles.contains(TextStyle.bold.rawValue))
                _editor.format(name: "italic", value: styles.contains(TextStyle.italic.rawValue))
                _editor.format(name: "underline", value: styles.contains(TextStyle.underline.rawValue))
                _editor.format(name: "strike", value: styles.contains(TextStyle.strikeThrough.rawValue))
            }
        case "format":
            if let args = call.arguments as? [String: Any] {
                let name = args["name"] as? String
                let value = args["value"]
                if name == nil || value == nil {
                    return
                }
                _editor.format(name: name!, value: value!)
            }
        case "formatText":
            if let args = call.arguments as? Dictionary<String, Any> {
                let index = args["index"] as? Int
                let length = args["len"] as? Int
                let name = args["name"] as? String
                let value = args["value"]
                if index == nil || length == nil || name == nil || value == nil {
                    return
                }
                _editor.formatText(index: index!, length: length!, name: name!, value: value!)
            }
            
        // Selection related.
        case "updateSelection":
            if let args = call.arguments as? Dictionary<String, Any> {
                let selStart = args["selStart"] as? Int
                let selEnd = args["selEnd"] as? Int
                if selStart == nil || selEnd == nil {
                    return
                }
                if selEnd! > selStart! {
                    _editor.setSelection(index: selStart!, length: selEnd! - selStart!)
                } else {
                    _editor.setSelection(index: selEnd!, length: selStart! - selEnd!)
                }
            }

        // Editor related.
        case "focus":
            _editor.focus()
        case "blur":
            _editor.blur()
        case "scrollTo":
            if let offset = call.arguments as? Int {
                _editor.scrollView.setContentOffset(CGPoint(x: 0, y: offset), animated: true)
            }
        case "scrollToTop":
            _editor.scrollView.setContentOffset(CGPoint(x: 0, y: 0), animated: true)
        case "scrollToBottom":
            let offset = CGPoint(x: 0, y: _editor.scrollView.contentSize.height - _editor.frame.size.height)
            _editor.scrollView.setContentOffset(offset, animated: true)
            
        default:
            print("missing tun editor method")
        }
    }

}
