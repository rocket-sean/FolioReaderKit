//
//  FolioReaderWebView.swift
//  FolioReaderKit
//
//  Created by Hans Seiffert on 21.09.16.
//  Copyright (c) 2016 Folio Reader. All rights reserved.
//

import WebKit

public typealias JSCallback = ((String?) ->())

/// The custom WebView used in each page
open class FolioReaderWebView: WKWebView {
    var isColors = false
    var isShare = false
    var isOneWord = false
    
    fileprivate(set) var cssOverflowProperty = "scroll"

    fileprivate weak var readerContainer: FolioReaderContainer?

    fileprivate var readerConfig: FolioReaderConfig {
        guard let readerContainer = readerContainer else { return FolioReaderConfig() }
        return readerContainer.readerConfig
    }

    fileprivate var book: FRBook {
        guard let readerContainer = readerContainer else { return FRBook() }
        return readerContainer.book
    }

    fileprivate var folioReader: FolioReader {
        guard let readerContainer = readerContainer else { return FolioReader() }
        return readerContainer.folioReader
    }

    init(frame: CGRect, readerContainer: FolioReaderContainer) {
        self.readerContainer = readerContainer
        
        let configuration = WKWebViewConfiguration()
        // pass WKWebViewConfiguration to app to let the app set scheme handler, we use that to load css or images in streaming reading mode
        self.readerContainer?.readerConfig.fileDelegate?.setURLSchemeHandler( config: configuration)
        super.init(frame: frame, configuration: configuration)

        if #available(iOS 16.4, *) {
            self.isInspectable = true
        }
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - UIMenuController

    open override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        guard readerConfig.useReaderMenuController else {
            return super.canPerformAction(action, withSender: sender)
        }

        if isShare {
            return false
        } else if isColors {
            return false
        } else {
            if action == #selector(highlight(_:))
                || action == #selector(highlightWithNote(_:))
                || action == #selector(updateHighlightNote(_:))
                || (action == #selector(define(_:)) && isOneWord)
                || (action == #selector(play(_:)) && (book.hasAudio || readerConfig.enableTTS))
                || (action == #selector(share(_:)) && readerConfig.allowSharing)
                || (action == #selector(copy(_:)) && readerConfig.allowSharing) {
                return true
            }
            return false
        }
    }

    // MARK: - UIMenuController - Actions

    @objc func share(_ sender: UIMenuController?) {
        guard let sender = sender else {
            return
        }

        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        let shareImage = UIAlertAction(title: self.readerConfig.localizedShareImageQuote, style: .default, handler: { (action) -> Void in
            if self.isShare {
                self.js("getHighlightContent()") { textToShare in
                    guard let textToShare = textToShare else { return }
                    self.folioReader.readerCenter?.presentQuoteShare(textToShare)
                }
            } else {
                self.js("getSelectedText()") { textToShare in
                    guard let textToShare = textToShare else { return }
                    self.folioReader.readerCenter?.presentQuoteShare(textToShare)
                    self.clearTextSelection()
                }
            }
            self.setMenuVisible(false)
        })

        let shareText = UIAlertAction(title: self.readerConfig.localizedShareTextQuote, style: .default) { (action) -> Void in
            if self.isShare {
                self.js("getHighlightContent()") { textToShare in
                    guard let textToShare = textToShare else { return }
                    self.folioReader.readerCenter?.shareHighlight(textToShare, rect: sender.menuFrame)
                }
            } else {
                self.js("getSelectedText()") { textToShare in
                    guard let textToShare = textToShare else { return }
                    self.folioReader.readerCenter?.shareHighlight(textToShare, rect: sender.menuFrame)
                }
            }
            self.setMenuVisible(false)
        }

        let cancel = UIAlertAction(title: self.readerConfig.localizedCancel, style: .cancel, handler: nil)

        alertController.addAction(shareImage)
        alertController.addAction(shareText)
        alertController.addAction(cancel)

        if let alert = alertController.popoverPresentationController {
            alert.sourceView = self.folioReader.readerCenter?.currentPage
            alert.sourceRect = sender.menuFrame
        }
        alertController.modalPresentationStyle = .fullScreen
        self.folioReader.readerCenter?.present(alertController, animated: true, completion: nil)
    }

    func colors(_ sender: UIMenuController?) {
        isColors = true
        createMenu(options: false)
        setMenuVisible(true)
    }

    func remove(_ sender: UIMenuController?) {
        js("removeThisHighlight()") { removedId in
            guard let removedId = removedId else { return }
            Highlight.removeById(withConfiguration: self.readerConfig, highlightId: removedId)
        }
        setMenuVisible(false)

    }
 
    @objc func addHighlight(_ sender: UIMenuController?, completion: @escaping (Highlight?) -> Void) {
        // Persist
        guard let bookId = self.book.bookId else {
            completion(nil)
            return
        }
        let pageNumber = folioReader.readerCenter?.currentPageNumber ?? 0
        let migrationPageNumber = max(0, pageNumber - 1)

        js("highlightString('\(HighlightStyle.classForStyle(self.folioReader.currentHighlightStyle))', '\(bookId)', \(migrationPageNumber) )") { highlightAndReturn in
        guard let jsonData = highlightAndReturn?.data(using: String.Encoding.utf8) else {
            return
        }
        do {
            guard let json = try JSONSerialization.jsonObject(with: jsonData, options: []) as? NSArray,
                let dic = json.firstObject as? [String: String]
            else {
                completion(nil)
                return
            }
            guard let rangies = dic["rangy"] else {
                completion(nil)
                return
            }
            guard let text = dic["content"] else {
                completion(nil)
                return
            }
            guard let identifier = dic["id"] else {
                completion(nil)
                return
            }
            if let dicRect = dic["rect"] {
                let rect = CGRectFromString(dicRect)
                self.createMenu(options: true)
                self.setMenuVisible(true, andRect: rect)
            }
            // MARK: Move to method
            // get matching rang
            var rangeString = FolioUtils.getRangy(rangies, with: identifier)
            // New id - migration to sync highlight
            var rangy = rangeString
            rangy = rangy.replacingOccurrences(of: Highlight.typeTextContentWithLine, with: "")
            let elements = rangy.split(separator: "$")
            var newId = identifier
            if elements.count >= 2 {
                newId = bookId + "_" + String(migrationPageNumber) + "_"
                newId += elements[0] + "_"
                newId += elements[1]
            }
            if elements.count >= 3 {
                var newRangeString = rangeString.split(separator: "$")
                newRangeString[2] = Substring.init(newId)
                rangeString = newRangeString.joined(separator: "$")
            }
            let match = Highlight.MatchingHighlight(text: text, id: newId, bookId: bookId, currentPage: migrationPageNumber, rangy:  rangeString)
            let highlight = Highlight.matchHighlight(match)
            highlight?.filePath = self.folioReader.readerCenter?.currentPage?.resource?.href
            completion(highlight)
            return
            
        } catch {
            print("Could not receive JSON")
        }
        }
        completion(nil)
        return

    }

    @objc func highlight(_ sender: UIMenuController?) {
        addHighlight(sender) { highlight in
        	highlight?.persist(withConfiguration: self.readerConfig)
        }
    }
    
    @objc func highlightWithNote(_ sender: UIMenuController?) {
        addHighlight(sender) { highlight in
        	guard let highlight = highlight else { return }
           	self.folioReader.readerCenter?.presentAddHighlightNote(highlight, edit: false)
        }
    }
    
    @objc func updateHighlightNote (_ sender: UIMenuController?) {
        js("currentHighlightId()") { highlightId in
            guard let highlightId = highlightId else { return }
            if let highlightNote = Highlight.getById(withConfiguration: self.readerConfig, highlightId: highlightId) {
            	self.folioReader.readerCenter?.presentAddHighlightNote(highlightNote, edit: true)
        	}
        }
    }

    @objc func define(_ sender: UIMenuController?) {
        js("getSelectedText()") { selectedText in
        	guard let selectedText = selectedText else { return }
            self.setMenuVisible(false)
            self.clearTextSelection()

            let vc = UIReferenceLibraryViewController(term: selectedText)
            vc.view.tintColor = self.readerConfig.tintColor
            guard let readerContainer = self.readerContainer else { return }
            readerContainer.show(vc, sender: nil)
        }
    }

    @objc func play(_ sender: UIMenuController?) {
        self.folioReader.readerAudioPlayer?.play()

        self.clearTextSelection()
    }

    func setYellow(_ sender: UIMenuController?) {
        changeHighlightStyle(sender, style: .yellow)
    }

    func setGreen(_ sender: UIMenuController?) {
        changeHighlightStyle(sender, style: .green)
    }

    func setBlue(_ sender: UIMenuController?) {
        changeHighlightStyle(sender, style: .blue)
    }

    func setPink(_ sender: UIMenuController?) {
        changeHighlightStyle(sender, style: .pink)
    }

    func setUnderline(_ sender: UIMenuController?) {
        changeHighlightStyle(sender, style: .underline)
    }

    func changeHighlightStyle(_ sender: UIMenuController?, style: HighlightStyle) {
        self.folioReader.currentHighlightStyle = style.rawValue

        js("setHighlightStyle('\(HighlightStyle.classForStyle(style.rawValue))')") { updateId in
            guard let updateId = updateId else { return }
            self.js("getHighlights()") { rangies in
                guard let rangies = rangies else { return }
                let rangeString = FolioUtils.getRangy(rangies, with: updateId)
                Highlight.updateById(withConfiguration: self.readerConfig, highlightId: updateId, rangy: rangeString)
            }
        }
        
        //FIX: https://github.com/FolioReader/FolioReaderKit/issues/316
        setMenuVisible(false)
    }

    // MARK: - Create and show menu

    private let menuController = UIMenuController.shared

    private lazy var highlightItem = UIMenuItem(title: self.readerConfig.localizedHighlightMenu, action: #selector(highlight(_:)))
    private lazy var highlightNoteItem = UIMenuItem(title: self.readerConfig.localizedHighlightNote, action: #selector(highlightWithNote(_:)))
    private lazy var editNoteItem = UIMenuItem(title: self.readerConfig.localizedHighlightNote, action: #selector(updateHighlightNote(_:)))
    private lazy var playAudioItem = UIMenuItem(title: self.readerConfig.localizedPlayMenu, action: #selector(play(_:)))
    private lazy var defineItem = UIMenuItem(title: self.readerConfig.localizedDefineMenu, action: #selector(define(_:)))

    private lazy var colorsItem = UIMenuItem(title: "C", image: UIImage(readerImageNamed: "colors-marker")) { [weak self] _ in
        self?.colors(self?.menuController)
    }
    private lazy var shareItem = UIMenuItem(title: "S", image: UIImage(readerImageNamed: "share-marker")) { [weak self] _ in
        self?.share(self?.menuController)
    }
    private lazy var removeItem = UIMenuItem(title: "R", image: UIImage(readerImageNamed: "no-marker")) { [weak self] _ in
        self?.remove(self?.menuController)
    }
    private lazy var yellowItem = UIMenuItem(title: "Y", image: UIImage(readerImageNamed: "yellow-marker")) { [weak self] _ in
        self?.setYellow(self?.menuController)
    }
    private lazy var greenItem = UIMenuItem(title: "G", image: UIImage(readerImageNamed: "green-marker")) { [weak self] _ in
        self?.setGreen(self?.menuController)
    }
    private lazy var blueItem = UIMenuItem(title: "B", image: UIImage(readerImageNamed: "blue-marker")) { [weak self] _ in
        self?.setBlue(self?.menuController)
    }
    private lazy var pinkItem = UIMenuItem(title: "P", image: UIImage(readerImageNamed: "pink-marker")) { [weak self] _ in
        self?.setPink(self?.menuController)
    }
    private lazy var underlineItem = UIMenuItem(title: "U", image: UIImage(readerImageNamed: "underline-marker")) { [weak self] _ in
        self?.setUnderline(self?.menuController)
    }

    func createMenu(options: Bool) {
        guard (self.readerConfig.useReaderMenuController == true) else {
            return
        }

        isShare = options

        var menuItems: [UIMenuItem] = []

        // menu on existing highlight
        if isShare {
            menuItems = [colorsItem, editNoteItem, removeItem]
            
            if (self.readerConfig.allowSharing == true) {
                menuItems.append(shareItem)
            }
            
            isShare = false
        } else if isColors {
            // menu for selecting highlight color
            menuItems = [yellowItem, greenItem, blueItem, pinkItem, underlineItem]
        } else {
            // default menu
            menuItems = [highlightItem, defineItem, highlightNoteItem]

            if self.book.hasAudio || self.readerConfig.enableTTS {
                menuItems.insert(playAudioItem, at: 0)
            }

            if (self.readerConfig.allowSharing == true) {
                menuItems.append(shareItem)
            }
        }

        menuController.menuItems = menuItems
    }
    
    open func setMenuVisible(_ menuVisible: Bool, animated: Bool = true, andRect rect: CGRect = CGRect.zero) {
        if !menuVisible {
            isColors = false
            isShare = false

            createMenu(options: false)
        }
        
        if menuVisible && !rect.equalTo(CGRect.zero) {
            UIMenuController.shared.setTargetRect(rect, in: self)
        }
        
        UIMenuController.shared.setMenuVisible(menuVisible, animated: animated)
    }
    
    
    // MARK: WebView
    
    func clearTextSelection() {
        // Forces text selection clearing
        // @NOTE: this doesn't seem to always work
        
        self.isUserInteractionEnabled = false
        self.isUserInteractionEnabled = true
    }
    
    func setupScrollDirection() {
        switch self.readerConfig.scrollDirection {
        case .vertical, .defaultVertical, .horizontalWithVerticalContent:
            scrollView.isPagingEnabled = false
            cssOverflowProperty = "scroll"
            scrollView.bounces = true
            break
        case .horizontal:
            scrollView.isPagingEnabled = true
            cssOverflowProperty = "-webkit-paged-x"
            scrollView.bounces = false
            break
        }

        FolioReaderScript.cssInjection(overflow: cssOverflowProperty).addIfNeeded(to: self)
        reload()
    }
}
