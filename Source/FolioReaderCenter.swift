//
//  FolioReaderCenter.swift
//  FolioReaderKit
//
//  Created by Heberti Almeida on 08/04/15.
//  Copyright (c) 2015 Folio Reader. All rights reserved.
//

import UIKit
import ZFDragableModalTransition

/// Protocol which is used from `FolioReaderCenter`s.
@objc public protocol FolioReaderCenterDelegate: class {

    /// Notifies that a page appeared. This is triggered when a page is chosen and displayed.
    ///
    /// - Parameter page: The appeared page
    @objc optional func pageDidAppear(_ page: FolioReaderPage, isFirstLoad: Bool, center: FolioReaderCenter)

    /// Passes and returns the HTML content as `String`. Implement this method if you want to modify the HTML content of a `FolioReaderPage`.
    ///
    /// - Parameters:
    ///   - page: The `FolioReaderPage`.
    ///   - htmlContent: The current HTML content as `String`.
    /// - Returns: The adjusted HTML content as `String`. This is the content which will be loaded into the given `FolioReaderPage`.
    @objc optional func htmlContentForPage(_ page: FolioReaderPage, htmlContent: String, center: FolioReaderCenter) -> String
    
    /// Notifies that a page changed. This is triggered when collection view cell is changed.
    ///
    /// - Parameter pageNumber: The appeared page item
    @objc optional func pageItemChanged(_ pageNumber: Int, center: FolioReaderCenter)
    
    /// Notifies that a navigation bar buttons did setup.
    ///
    /// - Parameter page: The appeared page
    @objc optional func navigationBarButtonsDidConfigure(center: FolioReaderCenter)
    
    @objc optional func didSelectHighlight(highlight: Highlight, center: FolioReaderCenter)
    
    @objc optional func searchingDidStart(keyword: String, book: FRBook, center: FolioReaderCenter)
    @objc optional func searchingDidReturn(keyword: String, book: FRBook, center: FolioReaderCenter)
    @objc optional func didSelectSearchResult(keyword: String, book: FRBook, chapterName: String, center: FolioReaderCenter)

}

/// The base reader class
open class FolioReaderCenter: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    /// This delegate receives the events from the current `FolioReaderPage`s delegate.
    open weak var delegate: FolioReaderCenterDelegate?

    /// This delegate receives the events from current page
    open weak var pageDelegate: FolioReaderPageDelegate?

    /// The base reader container
    open weak var readerContainer: FolioReaderContainer?

    /// The current visible page on reader
    open fileprivate(set) var currentPage: FolioReaderPage?
    
    /// The collection view with pages
    open var collectionView: UICollectionView!
    
    open var rwBook: FolioRWBook?
    var lastReadRangy: String?
    
    let collectionViewLayout = UICollectionViewFlowLayout()
    var loadingView: UIActivityIndicatorView!
    var pages: [String]!
    var totalPages: Int = 0
    var tempFragment: String?
    var tempAnchor: String?
    var animator: ZFModalTransitionAnimator!
    var pageIndicatorView: FolioReaderPageIndicator?
    var pageIndicatorHeight: CGFloat = 20
    var recentlyScrolled = false
    var recentlyScrolledDelay = 2.0 // 2 second delay until we clear recentlyScrolled
    var recentlyScrolledTimer: Timer!
    var scrollScrubber: ScrollScrubber?
    var activityIndicator = UIActivityIndicatorView()
    var isScrolling = false
    var pageScrollDirection = ScrollDirection()
    var nextPageNumber: Int = 0
    var previousPageNumber: Int = 0
    var currentPageNumber: Int = 0
    var pageWidth: CGFloat = 0.0
    var pageHeight: CGFloat = 0.0
    
    // Added by DungLe
    var shouldDelayScrollingToBottomUntilWebViewDidLoad: Bool = false
    var webViewDidLoadData: [IndexPath: Bool] = [:]
    private var tempSearchResult: FolioSearchResult?
    private var searchView: UINavigationController?
    private var searchItem: UIBarButtonItem?
    open var allowSearchThisBook: Bool = false {
        didSet {
            DispatchQueue.runTaskOnMainThread {
                self.configureNavBarButtons()
            }
        }
    }
    // End
    
    fileprivate var screenBounds: CGRect!
    fileprivate var pointNow = CGPoint.zero
    fileprivate var pageOffsetRate: CGFloat = 0
    fileprivate var tempReference: FRTocReference?
    fileprivate var isFirstLoad = true
    fileprivate var currentWebViewScrollPositions = [Int: CGPoint]()
    fileprivate var currentOrientation: UIInterfaceOrientation?

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

    // MARK: - Init

    init(withContainer readerContainer: FolioReaderContainer) {
        self.readerContainer = readerContainer
        self.rwBook = readerContainer.rwBook
        super.init(nibName: nil, bundle: Bundle.frameworkBundle())

        self.initialization()
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("This class doesn't support NSCoding.")
    }

    /**
     Common Initialization
     */
    fileprivate func initialization() {

        if (self.readerConfig.hideBars == true) {
            self.pageIndicatorHeight = 0
        }
        
        self.totalPages = book.spine.spineReferences.count

        // Loading indicator
        let style: UIActivityIndicatorViewStyle = folioReader.isNight(.white, .gray)
        loadingView = UIActivityIndicatorView(activityIndicatorStyle: style)
        loadingView.hidesWhenStopped = true
        loadingView.startAnimating()
        self.view.addSubview(loadingView)
    }

    // MARK: - View life cicle

    override open func viewDidLoad() {
        super.viewDidLoad()

        screenBounds = self.getScreenBounds()
        
        setPageSize(UIApplication.shared.statusBarOrientation)

        // Layout
        collectionViewLayout.sectionInset = UIEdgeInsets.zero
        collectionViewLayout.minimumLineSpacing = 0
        collectionViewLayout.minimumInteritemSpacing = 0
        collectionViewLayout.scrollDirection = .direction(withConfiguration: self.readerConfig)
        
        let background = folioReader.isNight(self.readerConfig.nightModeBackground, UIColor.white)
        view.backgroundColor = background

        // CollectionView
        collectionView = UICollectionView(frame: screenBounds, collectionViewLayout: collectionViewLayout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.isPagingEnabled = true
        collectionView.showsVerticalScrollIndicator = false
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.backgroundColor = background
        collectionView.decelerationRate = UIScrollViewDecelerationRateFast
        enableScrollBetweenChapters(scrollEnabled: true)
        view.addSubview(collectionView)

        if #available(iOS 11.0, *) {
            collectionView.contentInsetAdjustmentBehavior = .never
        }

        // Activity Indicator
        self.activityIndicator.activityIndicatorViewStyle = .gray
        self.activityIndicator.hidesWhenStopped = true
        self.activityIndicator = UIActivityIndicatorView(frame: CGRect(x: screenBounds.size.width/2, y: screenBounds.size.height/2, width: 30, height: 30))
        self.activityIndicator.backgroundColor = UIColor.gray
        self.view.addSubview(self.activityIndicator)
        self.view.bringSubview(toFront: self.activityIndicator)

        if #available(iOS 10.0, *) {
            collectionView.isPrefetchingEnabled = false
        }

        // Register cell classes
        collectionView?.register(FolioReaderPage.self, forCellWithReuseIdentifier: kReuseCellIdentifier)

        // Configure navigation bar and layout
        collectionView.contentInsetAdjustmentBehavior = .never
        extendedLayoutIncludesOpaqueBars = true
        configureNavBar()

        // Page indicator view
        if (self.readerConfig.hidePageIndicator == false) {
            let frame = self.frameForPageIndicatorView()
            pageIndicatorView = FolioReaderPageIndicator(frame: frame, readerConfig: readerConfig, folioReader: folioReader)
            if let pageIndicatorView = pageIndicatorView {
                view.addSubview(pageIndicatorView)
            }
        }

        guard let readerContainer = readerContainer else { return }
        self.scrollScrubber = ScrollScrubber(frame: frameForScrollScrubber(), withReaderContainer: readerContainer)
        self.scrollScrubber?.delegate = self
        if let scrollScrubber = scrollScrubber {
            view.addSubview(scrollScrubber.slider)
        }
    }

    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        configureNavBar()

        // Update pages
        pagesForCurrentPage(currentPage)
        pageIndicatorView?.reloadView(updateShadow: true)
    }

    override open func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        screenBounds = self.getScreenBounds()
        loadingView.center = view.center

        setPageSize(UIApplication.shared.statusBarOrientation)
        updateSubviewFrames()
    }

    // MARK: Layout

    /**
     Enable or disable the scrolling between chapters (`FolioReaderPage`s). If this is enabled it's only possible to read the current chapter. If another chapter should be displayed is has to be triggered programmatically with `changePageWith`.

     - parameter scrollEnabled: `Bool` which enables or disables the scrolling between `FolioReaderPage`s.
     */
    open func enableScrollBetweenChapters(scrollEnabled: Bool) {
        self.collectionView.isScrollEnabled = scrollEnabled
    }

    fileprivate func updateSubviewFrames() {
        self.pageIndicatorView?.frame = self.frameForPageIndicatorView()
        self.scrollScrubber?.frame = self.frameForScrollScrubber()
    }

    fileprivate func frameForPageIndicatorView() -> CGRect {
        var bounds = CGRect(x: 0, y: screenBounds.size.height-pageIndicatorHeight, width: screenBounds.size.width, height: pageIndicatorHeight)
        
        if #available(iOS 11.0, *) {
            bounds.size.height = bounds.size.height + view.safeAreaInsets.bottom
        }
        
        return bounds
    }

    fileprivate func frameForScrollScrubber() -> CGRect {
        let scrubberY: CGFloat = ((self.readerConfig.shouldHideNavigationOnTap == true || self.readerConfig.hideBars == true) ? 50 : 74)
        return CGRect(x: self.pageWidth + 10, y: scrubberY, width: 40, height: (self.pageHeight - 100))
    }

    func configureNavBar() {
        let navBackground = folioReader.isNight(self.readerConfig.nightModeMenuBackground, UIColor.white)
        let tintColor = readerConfig.tintColor
        let navText = readerConfig.tintColor
        let font = UIFont.systemFont(ofSize: 14, weight: .medium)
        setupNavigation(color: navBackground, tintColor: tintColor, titleColor: navText, andFont: font)
    }

    func configureNavBarButtons() {

        // Navbar buttons
        let shareIcon = UIImage(readerImageNamed: "icon-navbar-share")?.ignoreSystemTint(withConfiguration: self.readerConfig)
        let audioIcon = UIImage(readerImageNamed: "icon-navbar-tts")?.ignoreSystemTint(withConfiguration: self.readerConfig) //man-speech-icon
        let closeIcon = UIImage(readerImageNamed: "icon-navbar-close")?.ignoreSystemTint(withConfiguration: self.readerConfig)
        let tocIcon = UIImage(readerImageNamed: "icon-navbar-toc")?.ignoreSystemTint(withConfiguration: self.readerConfig)
        let fontIcon = UIImage(readerImageNamed: "icon-navbar-font")?.ignoreSystemTint(withConfiguration: self.readerConfig)
        let imageSearch = UIImage(readerImageNamed: "icon-navbar-search")
        let space = 70 as CGFloat

        let menu = UIBarButtonItem(image: closeIcon, style: .plain, target: self, action:#selector(closeReader(_:)))
        let toc = UIBarButtonItem(image: tocIcon, style: .plain, target: self, action:#selector(presentChapterList(_:)))
        searchItem = UIBarButtonItem(image: imageSearch, style: .plain, target: self, action: #selector(didSelectSearch(_:)))
        searchItem?.tintColor = readerConfig.tintColor
        
        navigationItem.leftBarButtonItems = self.allowSearchThisBook
            ? [menu, toc, searchItem ?? UIBarButtonItem()] : [menu, toc]

        var rightBarIcons = [UIBarButtonItem]()

        if (self.readerConfig.allowSharing == true) {
            rightBarIcons.append(UIBarButtonItem(image: shareIcon, style: .plain, target: self, action:#selector(shareChapter(_:))))
        }

        if self.book.hasAudio || self.readerConfig.enableTTS {
            rightBarIcons.append(UIBarButtonItem(image: audioIcon, style: .plain, target: self, action:#selector(presentPlayerMenu(_:))))
        }

        let font = UIBarButtonItem(image: fontIcon, style: .plain, target: self, action: #selector(presentFontsMenu))
        font.width = space

        rightBarIcons.append(contentsOf: [font])
        navigationItem.rightBarButtonItems = rightBarIcons
        
        if(self.readerConfig.displayTitle){
            navigationItem.title = rwBook?.title ?? book.title
        }
        self.delegate?.navigationBarButtonsDidConfigure?(center: self)
    }

    func reloadData() {
        self.loadingView.stopAnimating()
        self.totalPages = book.spine.spineReferences.count

        self.collectionView.reloadData()
        self.configureNavBarButtons()
        self.setCollectionViewProgressiveDirection()

        if isFirstLoad,
           self.readerConfig.loadSavedPositionForCurrentBook {
            guard let lastRead = FolioLastRead.lastRead(from: self.rwBook?.id ?? 0),
                lastRead.page >= 0 else {
                self.currentPageNumber = 1
                return
            }
            let pageNumber = lastRead.page + 1
//            guard let position = folioReader.savedPositionForCurrentBook, let pageNumber = position["pageNumber"] as? Int, pageNumber > 0 else {
//                self.currentPageNumber = 1
//                return
//            }
            self.changePageWith(page: pageNumber)
            self.currentPageNumber = pageNumber
        }
    }

    // MARK: Change page progressive direction

    private func transformViewForRTL(_ view: UIView?) {
        if folioReader.needsRTLChange {
            view?.transform = CGAffineTransform(scaleX: -1, y: 1)
        } else {
            view?.transform = CGAffineTransform.identity
        }
    }

    func setCollectionViewProgressiveDirection() {
        self.transformViewForRTL(self.collectionView)
    }

    func setPageProgressiveDirection(_ page: FolioReaderPage) {
        self.transformViewForRTL(page)
    }

    // MARK: Change layout orientation

    /// Get internal page offset before layout change
    private func updatePageOffsetRate() {
        guard let currentPage = self.currentPage, let webView = currentPage.webView else {
            return
        }

        let pageScrollView = webView.scrollView
        let contentSize = pageScrollView.contentSize.forDirection(withConfiguration: self.readerConfig)
        let contentOffset = pageScrollView.contentOffset.forDirection(withConfiguration: self.readerConfig)
        self.pageOffsetRate = (contentSize != 0 ? (contentOffset / contentSize) : 0)
    }

    func setScrollDirection(_ direction: FolioReaderScrollDirection) {
        updatePageOffsetRate()
        collectionView.isHidden = true
        let pageNumber = currentPageNumber
        readerConfig.scrollDirection = direction
        collectionViewLayout.scrollDirection = .direction(withConfiguration: self.readerConfig)
        collectionView.collectionViewLayout.invalidateLayout()
        reloadData()
        changePageWith(page: pageNumber)
        currentPage?.webView?.removeFromSuperview()
        currentPage?.webView = nil
        _ = configure(readerPageCell: currentPage, atIndexPath: IndexPath(row: pageNumber-1, section: 0))
        delay(0.5) {
            self.fixPageOffset(animated: false)
            self.collectionView.isHidden = false
        }
    }

    // MARK: Status bar and Navigation bar

    func hideBars() {
        guard self.readerConfig.shouldHideNavigationOnTap == true else {
            return
        }

        self.updateBarsStatus(true)
    }

    func showBars() {
        self.configureNavBar()
        self.updateBarsStatus(false)
    }

    func toggleBars() {
        guard self.readerConfig.shouldHideNavigationOnTap == true else {
            return
        }

        let shouldHide = !self.navigationController!.isNavigationBarHidden
        if shouldHide == false {
            self.configureNavBar()
        }

        self.updateBarsStatus(shouldHide)
    }

    private func updateBarsStatus(_ shouldHide: Bool, shouldShowIndicator: Bool = false) {
        guard let readerContainer = readerContainer else { return }
        readerContainer.shouldHideStatusBar = shouldHide

        UIView.animate(withDuration: 0.25, animations: {
            readerContainer.setNeedsStatusBarAppearanceUpdate()

            // Show minutes indicator
            if (shouldShowIndicator == true) {
                self.pageIndicatorView?.minutesLabel.alpha = shouldHide ? 0 : 1
            }
        })
        self.navigationController?.setNavigationBarHidden(shouldHide, animated: true)
    }

    // MARK: UICollectionViewDataSource

    open func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    open func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return totalPages
    }

    open func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let reuseableCell = collectionView.dequeueReusableCell(withReuseIdentifier: kReuseCellIdentifier, for: indexPath) as? FolioReaderPage
        return self.configure(readerPageCell: reuseableCell, atIndexPath: indexPath)
    }

    private func configure(readerPageCell cell: FolioReaderPage?, atIndexPath indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = cell, let readerContainer = readerContainer else {
            return UICollectionViewCell()
        }

        cell.setup(withReaderContainer: readerContainer)
        cell.pageNumber = indexPath.row+1
        cell.webView?.scrollView.delegate = self
        if #available(iOS 11.0, *) {
            cell.webView?.scrollView.contentInsetAdjustmentBehavior = .never
        }
        cell.webView?.setupScrollDirection()
        cell.webView?.frame = cell.webViewFrame()
        cell.delegate = self
        cell.backgroundColor = .clear

        setPageProgressiveDirection(cell)
        guard book.spine.spineReferences.count > indexPath.row else {
            return cell
        }
        let resource = self.book.spine.spineReferences[indexPath.row].resource
        cell.resource = resource
        DispatchQueue.global(qos: .default).async {
            String.load(contentsOfFile: resource.fullHref, encoding: String.Encoding.utf8, config: self.readerConfig, completion: { (content, error) in
                DispatchQueue.global(qos: .default).async {
                    guard var html = content, !html.isEmpty else {
                        return
                    }
                    
                    // Inject viewport
                    let viewportTag = "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0, shrink-to-fit=no\">"
                    
                    let mediaOverlayStyleColors = "\"\(self.readerConfig.mediaOverlayColor.hexString(false))\", \"\(self.readerConfig.mediaOverlayColor.highlightColor().hexString(false))\""
                    
                    // Inject CSS and js
                    let jsFiles = ["rangy-core", "rangy-classapplier", "rangy-textrange", "rangy-highlighter", "rangy-serializer",  "Bridge", "mark" ]
                    
                    var jsFilesTags: String = ""
                    for jsFile in jsFiles {
                        let jsFilePath = Bundle.frameworkBundle().path(forResource: jsFile, ofType: "js")
                        let jsTag = "<script type=\"text/javascript\" src=\"\(jsFilePath!)\"></script>\n"
                        jsFilesTags.append( jsTag )
                    }
                    jsFilesTags.append( "<script type=\"text/javascript\">setMediaOverlayStyleColors(\(mediaOverlayStyleColors))</script>" )
                    
                    let cssFilePath = Bundle.frameworkBundle().path(forResource: "Style", ofType: "css")
                    let cssTag = "<link rel=\"stylesheet\" type=\"text/css\" href=\"\(cssFilePath!)\">"
                    
                    let toInject = "<head>\n\(cssTag)\n\(jsFilesTags)\n\(viewportTag)\n"
                    html = html.replacingOccurrences(of: "<head>", with: toInject)
                    
                    // Font class name
                    var classes = self.folioReader.currentFont.cssIdentifier
                    classes += " " + self.folioReader.currentMediaOverlayStyle.className()
                    
                    // Night mode
                    if self.folioReader.nightMode {
                        classes += " nightMode"
                    }
                    
                    // Font Size
                    classes += " \(self.folioReader.currentFontSize.cssIdentifier)"
                    
                    html = html.replacingOccurrences(of: "<html ", with: "<html class=\"\(classes)\"")
                    
                    // Let the delegate adjust the html string
                    if let modifiedHtmlContent = self.delegate?.htmlContentForPage?(cell, htmlContent: html, center: self) {
                        html = modifiedHtmlContent
                    }
                    DispatchQueue.main.async {
                        cell.loadHTMLString(html, baseURL: URL(fileURLWithPath: resource.fullHref.deletingLastPathComponent))
                    }
                }
            })
        }
        
        return cell
    }

    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        var size = CGSize(width: collectionView.frame.width, height: collectionView.frame.height)
        
        if #available(iOS 11.0, *) {
            let orientation = UIDevice.current.orientation
            
            if orientation == .portrait || orientation == .portraitUpsideDown {
                if readerConfig.scrollDirection == .horizontal {
                    size.height = size.height - view.safeAreaInsets.bottom
                }
            }
        }
        
        return size
    }
    
    // MARK: - Device rotation

    override open func willRotate(to toInterfaceOrientation: UIInterfaceOrientation, duration: TimeInterval) {
        guard folioReader.isReaderReady else { return }

        setPageSize(toInterfaceOrientation)
        updateCurrentPage()

        if self.currentOrientation == nil || (self.currentOrientation?.isPortrait != toInterfaceOrientation.isPortrait) {
            var pageIndicatorFrame = pageIndicatorView?.frame
            pageIndicatorFrame?.origin.y = ((screenBounds.size.height < screenBounds.size.width) ? (self.collectionView.frame.height - pageIndicatorHeight) : (self.collectionView.frame.width - pageIndicatorHeight))
            pageIndicatorFrame?.origin.x = 0
            pageIndicatorFrame?.size.width = ((screenBounds.size.height < screenBounds.size.width) ? (self.collectionView.frame.width) : (self.collectionView.frame.height))
            pageIndicatorFrame?.size.height = pageIndicatorHeight

            var scrollScrubberFrame = scrollScrubber?.slider.frame;
            scrollScrubberFrame?.origin.x = ((screenBounds.size.height < screenBounds.size.width) ? (screenBounds.size.width - 100) : (screenBounds.size.height + 10))
            scrollScrubberFrame?.size.height = ((screenBounds.size.height < screenBounds.size.width) ? (self.collectionView.frame.height - 100) : (self.collectionView.frame.width - 100))

            self.collectionView.collectionViewLayout.invalidateLayout()

            UIView.animate(withDuration: duration, animations: {
                // Adjust page indicator view
                if let pageIndicatorFrame = pageIndicatorFrame {
                    self.pageIndicatorView?.frame = pageIndicatorFrame
                    self.pageIndicatorView?.reloadView(updateShadow: true)
                }

                // Adjust scroll scrubber slider
                if let scrollScrubberFrame = scrollScrubberFrame {
                    self.scrollScrubber?.slider.frame = scrollScrubberFrame
                }

                // Adjust collectionView
                self.collectionView.contentSize = self.readerConfig.isDirection(
                    CGSize(width: self.pageWidth, height: self.pageHeight * CGFloat(self.totalPages)),
                    CGSize(width: self.pageWidth * CGFloat(self.totalPages), height: self.pageHeight),
                    CGSize(width: self.pageWidth * CGFloat(self.totalPages), height: self.pageHeight)
                )
                self.collectionView.setContentOffset(self.frameForPage(self.currentPageNumber).origin, animated: false)
                self.collectionView.collectionViewLayout.invalidateLayout()

                // Adjust internal page offset
                self.updatePageOffsetRate()
            })
        }

        self.currentOrientation = toInterfaceOrientation
    }

    override open func didRotate(from fromInterfaceOrientation: UIInterfaceOrientation) {
        guard folioReader.isReaderReady == true, let currentPage = currentPage else {
            return
        }

        // Update pages
        pagesForCurrentPage(currentPage)
        currentPage.refreshPageMode()

        scrollScrubber?.setSliderVal()

        fixPageOffset(animated: true)
    }

    private func fixPageOffset(animated: Bool) {
        guard let currentPage = currentPage else {
            return
        }

        // After rotation fix internal page offset
        var pageOffset = (currentPage.webView?.scrollView.contentSize.forDirection(withConfiguration: self.readerConfig) ?? 0) * pageOffsetRate

        // Fix the offset for paged scroll
        if (self.readerConfig.scrollDirection == .horizontal && self.pageWidth != 0) {
            let page = round(pageOffset / self.pageWidth)
            pageOffset = page * self.pageWidth
        }

        let pageOffsetPoint = self.readerConfig.isDirection(CGPoint(x: 0, y: pageOffset), CGPoint(x: pageOffset, y: 0), CGPoint(x: 0, y: pageOffset))
        currentPage.webView?.scrollView.setContentOffset(pageOffsetPoint, animated: animated)
    }

    override open func willAnimateRotation(to toInterfaceOrientation: UIInterfaceOrientation, duration: TimeInterval) {
        guard folioReader.isReaderReady else {
            return
        }

        self.collectionView.scrollToItem(at: IndexPath(row: self.currentPageNumber - 1, section: 0), at: UICollectionViewScrollPosition(), animated: false)
        if (self.currentPageNumber + 1) >= totalPages {
            UIView.animate(withDuration: duration, animations: {
                self.collectionView.setContentOffset(self.frameForPage(self.currentPageNumber).origin, animated: false)
            })
        }
    }

    // MARK: - Page

    func setPageSize(_ orientation: UIInterfaceOrientation) {
        guard orientation.isPortrait else {
            if screenBounds.size.width > screenBounds.size.height {
                self.pageWidth = screenBounds.size.width
                self.pageHeight = screenBounds.size.height
            } else {
                self.pageWidth = screenBounds.size.height
                self.pageHeight = screenBounds.size.width
            }
            return
        }

        if screenBounds.size.width < screenBounds.size.height {
            self.pageWidth = screenBounds.size.width
            self.pageHeight = screenBounds.size.height
        } else {
            self.pageWidth = screenBounds.size.height
            self.pageHeight = screenBounds.size.width
        }
    }

    func updateCurrentPage(_ page: FolioReaderPage? = nil, completion: (() -> Void)? = nil) {
        if let page = page {
            currentPage = page
            self.previousPageNumber = page.pageNumber-1
            self.currentPageNumber = page.pageNumber
        } else {
            let currentIndexPath = getCurrentIndexPath()
            currentPage = collectionView.cellForItem(at: currentIndexPath) as? FolioReaderPage

            self.previousPageNumber = currentIndexPath.row
            self.currentPageNumber = currentIndexPath.row+1
        }

        self.nextPageNumber = min(currentPageNumber + 1, totalPages - 1)

        // Set pages
        guard let currentPage = currentPage else {
            completion?()
            return
        }

        scrollScrubber?.setSliderVal()

//        if let readingTime = currentPage.webView?.js("getReadingTime()") {
//            pageIndicatorView?.totalMinutes = Int(readingTime)!
//        } else {
//            pageIndicatorView?.totalMinutes = 0
//        }
        pagesForCurrentPage(currentPage)

        delegate?.pageDidAppear?(currentPage, isFirstLoad: isFirstLoad, center: self)
        delegate?.pageItemChanged?(self.getCurrentPageItemNumber(), center: self)

        completion?()
    }

    func pagesForCurrentPage(_ page: FolioReaderPage?) {
        guard let page = page, let webView = page.webView else { return }

        let pageSize = self.readerConfig.isDirection(pageHeight, self.pageWidth, pageHeight)
        let contentSize = page.webView?.scrollView.contentSize.forDirection(withConfiguration: self.readerConfig) ?? 0
        self.pageIndicatorView?.totalPages = ((pageSize != 0) ? Int(ceil(contentSize / pageSize)) : 0)

        let pageOffSet = self.readerConfig.isDirection(webView.scrollView.contentOffset.x, webView.scrollView.contentOffset.x, webView.scrollView.contentOffset.y)
        let webViewPage = pageForOffset(pageOffSet, pageHeight: pageSize)

        self.pageIndicatorView?.currentPage = webViewPage
    }

    func pageForOffset(_ offset: CGFloat, pageHeight height: CGFloat) -> Int {
        guard (height != 0) else {
            return 0
        }

        let page = Int(ceil(offset / height))+1
        return page
    }

    func getCurrentIndexPath() -> IndexPath {
        let indexPaths = collectionView.indexPathsForVisibleItems
        var indexPath = IndexPath(row: 0, section: 0)

        guard let first = indexPaths.first else {
            return indexPath
        }

        switch indexPaths.count {
        case 0:
            break
        case 1:
            indexPath = first
        case 2:
            guard let second = indexPaths.last, abs(first.row - second.row) > 1 else {
                fallthrough
            }

            if first.row + 1 == currentPageNumber {
                indexPath = first
            } else if second.row + 1 == currentPageNumber {
                indexPath = second
            } else {
                fallthrough
            }
        default:
            switch self.pageScrollDirection {
            case .up, .left:
                indexPath = indexPaths.min()!
            default:
                indexPath = indexPaths.max()!
            }
        }

        return indexPath
    }

    func frameForPage(_ page: Int) -> CGRect {
        return self.readerConfig.isDirection(
            CGRect(x: 0, y: self.pageHeight * CGFloat(page-1), width: self.pageWidth, height: self.pageHeight),
            CGRect(x: self.pageWidth * CGFloat(page-1), y: 0, width: self.pageWidth, height: self.pageHeight),
            CGRect(x: 0, y: self.pageHeight * CGFloat(page-1), width: self.pageWidth, height: self.pageHeight)
        )
    }

    open func changePageWith(page: Int, andFragment fragment: String, animated: Bool = false, completion: (() -> Void)? = nil) {
        if (self.currentPageNumber == page) {
            if let currentPage = currentPage , fragment != "" {
                currentPage.scrollTo(fragment, animated: true)
            }
            completion?()
        } else {
            tempFragment = fragment
            changePageWith(page: page, animated: animated, completion: { () -> Void in
                self.updateCurrentPage {
                    completion?()
                }
            })
        }
    }
    
    
    open func changePageWith(page: Int, searchResult: FolioSearchResult, animated: Bool = false) {
        guard page < totalPages else {
            print("Failed to load book because the requested resource is missing.")
            return
        }
        // Scroll to a result in current page
        if self.currentPageNumber - 1 == page, page >= 0 {
            currentPage?.scrollTo(searchResult: searchResult, animated: true)
            return
        }
        // Load page at index path and scroll to result
        let indexPath = IndexPath(row: page, section: 0)
        changePageWith(indexPath: indexPath, animated: animated, completion: { () -> Void in
            self.updateCurrentPage()
        })
        tempSearchResult = searchResult
    }

    open func changePageWith(href: String, animated: Bool = false, completion: (() -> Void)? = nil) {
        guard let item = findPageByHref(href) else {
            return
        }
        let indexPath = IndexPath(row: item, section: 0)
        changePageWith(indexPath: indexPath, animated: animated, completion: { () -> Void in
            self.updateCurrentPage {
                completion?()
            }
        })
    }

    open func changePageWith(href: String, andAudioMarkID markID: String) {
        if recentlyScrolled { return } // if user recently scrolled, do not change pages or scroll the webview
        guard let currentPage = currentPage, let item = findPageByHref(href) else { return }

        let pageUpdateNeeded = item+1 != currentPage.pageNumber
        let indexPath = IndexPath(row: item, section: 0)
        changePageWith(indexPath: indexPath, animated: true) { () -> Void in
            if pageUpdateNeeded {
                self.updateCurrentPage {
                    currentPage.audioMarkID(markID)
                }
            } else {
                currentPage.audioMarkID(markID)
            }
        }
    }

    open func changePageWith(indexPath: IndexPath, animated: Bool = false, completion: (() -> Void)? = nil) {
        guard indexPathIsValid(indexPath) else {
            print("ERROR: Attempt to scroll to invalid index path")
            completion?()
            return
        }

        UIView.animate(withDuration: animated ? 0.3 : 0, delay: 0, options: UIViewAnimationOptions(), animations: {
            self.collectionView.scrollToItem(at: indexPath, at: .direction(withConfiguration: self.readerConfig), animated: false)
        }, completion: { finished -> Void in
            completion?()
        })
    }
    
    open func changePageWith(href: String, pageItem: Int, animated: Bool = false, completion: (() -> Void)? = nil) {
        changePageWith(href: href, animated: animated) {
            self.changePageItem(to: pageItem)
        }
    }

    func indexPathIsValid(_ indexPath: IndexPath) -> Bool {
        let section = indexPath.section
        let row = indexPath.row
        let lastSectionIndex = numberOfSections(in: collectionView) - 1

        //Make sure the specified section exists
        if section > lastSectionIndex {
            return false
        }

        let rowCount = self.collectionView(collectionView, numberOfItemsInSection: indexPath.section) - 1
        return row <= rowCount
    }

    open func isLastPage() -> Bool{
        return (currentPageNumber == self.nextPageNumber)
    }

    public func changePageToNext(_ completion: (() -> Void)? = nil) {
        changePageWith(page: self.nextPageNumber, animated: true) { () -> Void in
            completion?()
        }
    }

    public func changePageToPrevious(_ completion: (() -> Void)? = nil) {
        changePageWith(page: self.previousPageNumber, animated: true) { () -> Void in
            completion?()
        }
    }
    
    public func changePageItemToNext(_ completion: (() -> Void)? = nil) {
        // TODO: It was implemented for horizontal orientation.
        // Need check page orientation (v/h) and make correct calc for vertical
        guard
            let cell = collectionView.cellForItem(at: getCurrentIndexPath()) as? FolioReaderPage,
            let contentOffset = cell.webView?.scrollView.contentOffset,
            let contentOffsetXLimit = cell.webView?.scrollView.contentSize.width else {
                completion?()
                return
        }
        
        let cellSize = cell.frame.size
        let contentOffsetX = contentOffset.x + cellSize.width
        
        if contentOffsetX >= contentOffsetXLimit {
            changePageToNext(completion)
        } else {
            cell.scrollPageToOffset(contentOffsetX, animated: true)
        }
        
        completion?()
    }

    public func getCurrentPageItemNumber() -> Int {
        guard let page = currentPage, let webView = page.webView else { return 0 }
        
        let pageSize = readerConfig.isDirection(pageHeight, pageWidth, pageHeight)
        let pageOffSet = readerConfig.isDirection(webView.scrollView.contentOffset.x, webView.scrollView.contentOffset.x, webView.scrollView.contentOffset.y)
        let webViewPage = pageForOffset(pageOffSet, pageHeight: pageSize)
        
        return webViewPage
    }

    public func changePageItemToPrevious(_ completion: (() -> Void)? = nil) {
        // TODO: It was implemented for horizontal orientation.
        // Need check page orientation (v/h) and make correct calc for vertical
        guard
            let cell = collectionView.cellForItem(at: getCurrentIndexPath()) as? FolioReaderPage,
            let contentOffset = cell.webView?.scrollView.contentOffset else {
                completion?()
                return
        }
        
        let cellSize = cell.frame.size
        let contentOffsetX = contentOffset.x - cellSize.width
        
        if contentOffsetX < 0 {
            changePageToPrevious(completion)
        } else {
            cell.scrollPageToOffset(contentOffsetX, animated: true)
        }
        
        completion?()
    }

    public func changePageItemToLast(animated: Bool = true, _ completion: (() -> Void)? = nil) {
        // TODO: It was implemented for horizontal orientation.
        // Need check page orientation (v/h) and make correct calc for vertical
        guard
            let cell = collectionView.cellForItem(at: getCurrentIndexPath()) as? FolioReaderPage,
            let contentSize = cell.webView?.scrollView.contentSize else {
                completion?()
                return
        }
        
        let cellSize = cell.frame.size
        var contentOffsetX: CGFloat = 0.0
        
        if contentSize.width > 0 && cellSize.width > 0 {
            contentOffsetX = (cellSize.width * (contentSize.width / cellSize.width)) - cellSize.width
        }
        
        if contentOffsetX < 0 {
            contentOffsetX = 0
        }
        
        cell.scrollPageToOffset(contentOffsetX, animated: animated)
        
        completion?()
    }

    public func changePageItem(to: Int, animated: Bool = true, completion: (() -> Void)? = nil) {
        // TODO: It was implemented for horizontal orientation.
        // Need check page orientation (v/h) and make correct calc for vertical
        guard
            let cell = collectionView.cellForItem(at: getCurrentIndexPath()) as? FolioReaderPage,
            let contentSize = cell.webView?.scrollView.contentSize else {
                delegate?.pageItemChanged?(getCurrentPageItemNumber(), center: self)
                completion?()
                return
        }
        
        let cellSize = cell.frame.size
        var contentOffsetX: CGFloat = 0.0
        
        if contentSize.width > 0 && cellSize.width > 0 {
            contentOffsetX = (cellSize.width * CGFloat(to)) - cellSize.width
        }
        
        if contentOffsetX > contentSize.width {
            contentOffsetX = contentSize.width - cellSize.width
        }
        
        if contentOffsetX < 0 {
            contentOffsetX = 0
        }
        
        UIView.animate(withDuration: animated ? 0.3 : 0, delay: 0, options: UIViewAnimationOptions(), animations: { () -> Void in
            cell.scrollPageToOffset(contentOffsetX, animated: animated)
        }) { (finished: Bool) -> Void in
            self.updateCurrentPage {
                completion?()
            }
        }
    }

    /**
     Find a page by FRTocReference.
     */
    public func findPageByResource(_ reference: FRTocReference) -> Int? {
        var count = 0
        for item in self.book.spine.spineReferences {
            if let resource = reference.resource, item.resource == resource {
                return count + 1
            }
            count += 1
        }
        return nil
    }

    /**
     Find a page by href.
     */
    public func findPageByHref(_ href: String) -> Int? {
        var count = 0
        for item in self.book.spine.spineReferences {
            if item.resource.href == href {
                return count
            }
            count += 1
        }
        return nil
    }

    /**
     Find and return the current chapter resource.
     */
    public func getCurrentChapter() -> FRResource? {
        var foundResource: FRResource?

        func search(_ items: [FRTocReference]) {
            for item in items {
                guard foundResource == nil else { break }

                if let reference = book.spine.spineReferences[safe: (currentPageNumber - 1)], let resource = item.resource, resource == reference.resource {
                    foundResource = resource
                    break
                } else if let children = item.children, children.isEmpty == false {
                    search(children)
                }
            }
        }
        search(book.tableOfContents)

        return foundResource
    }

    /**
     Return the current chapter progress based on current chapter and total of chapters.
     */
    public func getCurrentChapterProgress() -> CGFloat {
        let total = totalPages
        let current = currentPageNumber
        
        if total == 0 {
            return 0
        }
        
        return CGFloat((100 * current) / total)
    }

    /**
     Find and return the current chapter name.
     */
    public func getCurrentChapterName() -> String? {
        for item in self.book.flatTableOfContents() {
            guard
                let reference = self.book.spine.spineReferences[safe: (self.currentPageNumber - 1)],
                let resource = item.resource,
                (resource == reference.resource),
                let title = item.title else {
                    continue
            }

            return title
        }

        return nil
    }

    // MARK: Public page methods

    /**
     Changes the current page of the reader.

     - parameter page: The target page index. Note: The page index starts at 1 (and not 0).
     - parameter animated: En-/Disables the animation of the page change.
     - parameter completion: A Closure which is called if the page change is completed.
     */
    public func changePageWith(page: Int, animated: Bool = false, completion: (() -> Void)? = nil) {
        if page > 0 && page-1 < totalPages {
            let indexPath = IndexPath(row: page-1, section: 0)
            changePageWith(indexPath: indexPath, animated: animated, completion: { () -> Void in
                self.updateCurrentPage {
                    completion?()
                }
            })
        }
    }

    // MARK: - Audio Playing

    func audioMark(href: String, fragmentID: String) {
        changePageWith(href: href, andAudioMarkID: fragmentID)
    }

    // MARK: - Sharing

    /**
     Sharing chapter method.
     */
    @objc func shareChapter(_ sender: UIBarButtonItem) {
        guard let currentPage = currentPage else { return }

       	currentPage.webView?.js("getBodyText()") { chapterText in
            guard let chapterText = chapterText else { return }
            let htmlText = chapterText.replacingOccurrences(of: "[\\n\\r]+", with: "<br />", options: .regularExpression)
            var subject = self.readerConfig.localizedShareChapterSubject
            var html = ""
            var text = ""
            var bookTitle = ""
            var chapterName = ""
            var authorName = ""
            var shareItems = [AnyObject]()

            // Get book title
            if let title = self.book.title {
                bookTitle = title
                subject += " “\(title)”"
            }

            // Get chapter name
            if let chapter = self.getCurrentChapterName() {
                chapterName = chapter
            }

            // Get author name
            if let author = self.book.metadata.creators.first {
                authorName = author.name
            }

            // Sharing html and text
            html = "<html><body>"
            html += "<br /><hr> <p>\(htmlText)</p> <hr><br />"
            html += "<center><p style=\"color:gray\">"+self.readerConfig.localizedShareAllExcerptsFrom+"</p>"
            html += "<b>\(bookTitle)</b><br />"
            html += self.readerConfig.localizedShareBy+" <i>\(authorName)</i><br />"

            if let bookShareLink = self.readerConfig.localizedShareWebLink {
                html += "<a href=\"\(bookShareLink.absoluteString)\">\(bookShareLink.absoluteString)</a>"
                shareItems.append(bookShareLink as AnyObject)
            }

            html += "</center></body></html>"
            text = "\(chapterName)\n\n“\(chapterText)” \n\n\(bookTitle) \n\(self.readerConfig.localizedShareBy) \(authorName)"

            let act = FolioReaderSharingProvider(subject: subject, text: text, html: html)
            shareItems.insert(contentsOf: [act, "" as AnyObject], at: 0)

            let activityViewController = UIActivityViewController(activityItems: shareItems, applicationActivities: nil)
            activityViewController.excludedActivityTypes = [UIActivityType.print, UIActivityType.postToVimeo]

            // Pop style on iPad
            if let actv = activityViewController.popoverPresentationController {
                actv.barButtonItem = sender
            }

            self.present(activityViewController, animated: true, completion: nil)
        }
    }

    /**
     Sharing highlight method.
     */
    func shareHighlight(_ string: String, rect: CGRect) {
        var subject = readerConfig.localizedShareHighlightSubject
        var html = ""
        var text = ""
        var bookTitle = ""
        var chapterName = ""
        var authorName = ""
        var shareItems = [AnyObject]()

        // Get book title
        if let title = self.book.title {
            bookTitle = title
            subject += " “\(title)”"
        }

        // Get chapter name
        if let chapter = getCurrentChapterName() {
            chapterName = chapter
        }

        // Get author name
        if let author = self.book.metadata.creators.first {
            authorName = author.name
        }

        // Sharing html and text
        html = "<html><body>"
        html += "<br /><hr> <p>\(chapterName)</p>"
        html += "<p>\(string)</p> <hr><br />"
        html += "<center><p style=\"color:gray\">"+readerConfig.localizedShareAllExcerptsFrom+"</p>"
        html += "<b>\(bookTitle)</b><br />"
        html += readerConfig.localizedShareBy+" <i>\(authorName)</i><br />"

        if let bookShareLink = readerConfig.localizedShareWebLink {
            html += "<a href=\"\(bookShareLink.absoluteString)\">\(bookShareLink.absoluteString)</a>"
            shareItems.append(bookShareLink as AnyObject)
        }

        html += "</center></body></html>"
        text = "\(chapterName)\n\n“\(string)” \n\n\(bookTitle) \n\(readerConfig.localizedShareBy) \(authorName)"

        let act = FolioReaderSharingProvider(subject: subject, text: text, html: html)
        shareItems.insert(contentsOf: [act, "" as AnyObject], at: 0)

        let activityViewController = UIActivityViewController(activityItems: shareItems, applicationActivities: nil)
        activityViewController.excludedActivityTypes = [UIActivityType.print, UIActivityType.postToVimeo]

        // Pop style on iPad
        if let actv = activityViewController.popoverPresentationController {
            actv.sourceView = currentPage
            actv.sourceRect = rect
        }

        present(activityViewController, animated: true, completion: nil)
    }

    // MARK: - ScrollView Delegate

    open func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
        scrollView.pinchGestureRecognizer?.isEnabled = false
    }
    
    open func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        self.isScrolling = true
        clearRecentlyScrolled()
        recentlyScrolled = true
        pointNow = scrollView.contentOffset

        if (scrollView is UICollectionView) {
            scrollView.isUserInteractionEnabled = false
        }
        
        if let currentPage = currentPage {
            currentPage.webView?.createMenu(options: true)
            currentPage.webView?.setMenuVisible(false)
        }

        scrollScrubber?.scrollViewWillBeginDragging(scrollView)
    }

    open func scrollViewDidScroll(_ scrollView: UIScrollView) {

        if (navigationController?.isNavigationBarHidden == false && scrollView.isDragging) {
            self.toggleBars()
        }

        scrollScrubber?.scrollViewDidScroll(scrollView)

        let isCollectionScrollView = (scrollView is UICollectionView)
        let scrollType: ScrollType = ((isCollectionScrollView == true) ? .chapter : .page)

        // Update current reading page
        if (isCollectionScrollView == false), let page = currentPage, let webView = page.webView {

            // deselect text selection
            webView.clearTextSelection()

            let pageSize = self.readerConfig.isDirection(self.pageHeight, self.pageWidth, self.pageHeight)
            let contentOffset = webView.scrollView.contentOffset.forDirection(withConfiguration: self.readerConfig)
            let contentSize = webView.scrollView.contentSize.forDirection(withConfiguration: self.readerConfig)
            if (contentOffset + pageSize <= contentSize) {

                let webViewPage = pageForOffset(contentOffset, pageHeight: pageSize)

                if (readerConfig.scrollDirection == .horizontalWithVerticalContent) {
                    let currentIndexPathRow = (page.pageNumber - 1)

                    // if the cell reload doesn't save the top position offset
                    if let oldOffSet = self.currentWebViewScrollPositions[currentIndexPathRow], (abs(oldOffSet.y - scrollView.contentOffset.y) > 100) {
                        // Do nothing
                    } else {
                        self.currentWebViewScrollPositions[currentIndexPathRow] = scrollView.contentOffset
                    }
                }

                if (pageIndicatorView?.currentPage != webViewPage) {
                    pageIndicatorView?.currentPage = webViewPage
                }
                
                self.delegate?.pageItemChanged?(webViewPage, center: self)
            }
        }

        self.updatePageScrollDirection(inScrollView: scrollView, forScrollType: scrollType)
    }

    private func updatePageScrollDirection(inScrollView scrollView: UIScrollView, forScrollType scrollType: ScrollType) {

        let scrollViewContentOffsetForDirection = scrollView.contentOffset.forDirection(withConfiguration: self.readerConfig, scrollType: scrollType)
        let pointNowForDirection = pointNow.forDirection(withConfiguration: self.readerConfig, scrollType: scrollType)
        // The movement is either positive or negative. This happens if the page change isn't completed. Toggle to the other scroll direction then.
        let isCurrentlyPositive = (self.pageScrollDirection == .left || self.pageScrollDirection == .up)

        if (scrollViewContentOffsetForDirection < pointNowForDirection) {
            self.pageScrollDirection = .negative(withConfiguration: self.readerConfig, scrollType: scrollType)
        } else if (scrollViewContentOffsetForDirection > pointNowForDirection) {
            self.pageScrollDirection = .positive(withConfiguration: self.readerConfig, scrollType: scrollType)
        } else if (isCurrentlyPositive == true) {
            self.pageScrollDirection = .negative(withConfiguration: self.readerConfig, scrollType: scrollType)
        } else {
            self.pageScrollDirection = .positive(withConfiguration: self.readerConfig, scrollType: scrollType)
        }
    }
    
    func trulyVisibleIndexPath() -> IndexPath? {
        for indexPath in collectionView.indexPathsForVisibleItems {
            guard let frame = collectionView.layoutAttributesForItem(at: indexPath)?.frame else {
                continue
            }
            let intersectRect = frame.intersection(CGRect(x: collectionView.contentOffset.x,
                                                          y: collectionView.contentOffset.y,
                                                          width: collectionView.bounds.size.width,
                                                          height: collectionView.bounds.size.height))
            if intersectRect.width > collectionView.bounds.size.width / 2 {
                return indexPath
            }
        }
        return nil
    }
    
    open func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        self.isScrolling = false
        
        if (scrollView is UICollectionView) {
            scrollView.isUserInteractionEnabled = true
        }
        
        // If web page is scroll from page n to page n-1, and it did finish load before
        // scrollViewDidEndDecelerating, keep track it
        let direction: ScrollDirection = self.folioReader.needsRTLChange ? .positive(withConfiguration: self.readerConfig) : .negative(withConfiguration: self.readerConfig)
        if self.folioReader.readerCenter?.pageScrollDirection == direction,
            self.readerConfig.scrollDirection != .horizontalWithVerticalContent,
            let visibleIdx = trulyVisibleIndexPath(),
            webViewDidLoadData[visibleIdx] != true {
            shouldDelayScrollingToBottomUntilWebViewDidLoad = true
        }
        
        // Perform the page after a short delay as the collection view hasn't completed it's transition if this method is called (the index paths aren't right during fast scrolls).
        delay(0.2, closure: { [weak self] in
            //TODO uncomented because of UIWebView usage
//            if (self?.readerConfig.scrollDirection == .horizontalWithVerticalContent),
//                let cell = ((scrollView.superview as? WKWebView)?.delegate as? FolioReaderPage) {
//                let currentIndexPathRow = cell.pageNumber - 1
//                self?.currentWebViewScrollPositions[currentIndexPathRow] = scrollView.contentOffset
//            }

            if (scrollView is UICollectionView) {
                guard let instance = self else {
                    return
                }
                
                if instance.totalPages > 0 {
                    instance.updateCurrentPage()
                    instance.delegate?.pageItemChanged?(instance.getCurrentPageItemNumber(), center: instance)
                }
            } else {
                self?.scrollScrubber?.scrollViewDidEndDecelerating(scrollView)
            }
        })
        
    }

    open func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        recentlyScrolledTimer = Timer(timeInterval:recentlyScrolledDelay, target: self, selector: #selector(FolioReaderCenter.clearRecentlyScrolled), userInfo: nil, repeats: false)
        RunLoop.current.add(recentlyScrolledTimer, forMode: RunLoopMode.commonModes)
    }

    @objc func clearRecentlyScrolled() {
        if(recentlyScrolledTimer != nil) {
            recentlyScrolledTimer.invalidate()
            recentlyScrolledTimer = nil
        }
        recentlyScrolled = false
    }

    open func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        scrollScrubber?.scrollViewDidEndScrollingAnimation(scrollView)
    }

    // MARK: NavigationBar Actions

    @objc open func closeReader(_ sender: UIBarButtonItem) {
        dismiss()
        folioReader.close()
        (searchView?.topViewController as? FolioReaderSearchView)?.willDeinitView()
    }

    /**
     Present chapter list
     */
    @objc func presentChapterList(_ sender: UIBarButtonItem) {
//        folioReader.saveReaderState()

        let chapter = FolioReaderChapterList(folioReader: folioReader, readerConfig: readerConfig, book: book, delegate: self)
        let highlight = FolioReaderHighlightList(folioReader: folioReader, readerConfig: readerConfig)
        highlight.delegate = self
        let pageController = PageViewController(folioReader: folioReader, readerConfig: readerConfig)

        pageController.viewControllerOne = chapter
        pageController.viewControllerTwo = highlight
        pageController.segmentedControlItems = [readerConfig.localizedContentsTitle, readerConfig.localizedHighlightsTitle]

        let nav = UINavigationController(rootViewController: pageController)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true, completion: nil)
    }

    /**
     Present fonts and settings menu
     */
    @objc func presentFontsMenu() {
//        folioReader.saveReaderState()
        hideBars()

        let menu = FolioReaderFontsMenu(folioReader: folioReader, readerConfig: readerConfig)
        menu.modalPresentationStyle = .overCurrentContext
        animator = ZFModalTransitionAnimator(modalViewController: menu)
        animator.isDragable = false
        animator.bounces = false
        animator.behindViewAlpha = 0.4
        animator.behindViewScale = 1
        animator.transitionDuration = 0.6
        animator.direction = ZFModalTransitonDirection.bottom

        menu.transitioningDelegate = animator
        self.present(menu, animated: true, completion: nil)
    }

    /**
     Present audio player menu
     */
    @objc func presentPlayerMenu(_ sender: UIBarButtonItem) {
//        folioReader.saveReaderState()
        hideBars()

        let menu = FolioReaderPlayerMenu(folioReader: folioReader, readerConfig: readerConfig)
        menu.modalPresentationStyle = .fullScreen

        animator = ZFModalTransitionAnimator(modalViewController: menu)
        animator.isDragable = true
        animator.bounces = false
        animator.behindViewAlpha = 0.4
        animator.behindViewScale = 1
        animator.transitionDuration = 0.6
        animator.direction = ZFModalTransitonDirection.bottom

        menu.transitioningDelegate = animator
        present(menu, animated: true, completion: nil)
    }

    /**
     Present Quote Share
     */
    func presentQuoteShare(_ string: String) {
        let quoteShare = FolioReaderQuoteShare(initWithText: string, readerConfig: readerConfig, folioReader: folioReader, book: book)
        let nav = UINavigationController(rootViewController: quoteShare)

        if UIDevice.current.userInterfaceIdiom == .pad {
            nav.modalPresentationStyle = .fullScreen
        }
        present(nav, animated: true, completion: nil)
    }
    
    /**
     Present add highlight note
     */
    func presentAddHighlightNote(_ highlight: Highlight, edit: Bool) {
        let addHighlightView = FolioReaderAddHighlightNote(withHighlight: highlight, folioReader: folioReader, readerConfig: readerConfig)
        addHighlightView.isEditHighlight = edit
        let nav = UINavigationController(rootViewController: addHighlightView)
        nav.modalPresentationStyle = .fullScreen
        
        present(nav, animated: true, completion: nil)
    }
    
    private func createSearchView() -> UINavigationController {
        let searchView = FolioReaderSearchView(folioReader: folioReader, readerConfig: readerConfig)
        let navigationController = UINavigationController(rootViewController: searchView)
        if UIDevice.current.userInterfaceIdiom == .phone {
            return navigationController
        }
        navigationController.navigationBar.barTintColor = #colorLiteral(red: 0.137254902, green: 0.3411764706, blue: 0.5882352941, alpha: 1)
        navigationController.navigationBar.titleTextAttributes = [NSAttributedStringKey.foregroundColor: UIColor.white , NSAttributedStringKey.font: UIFont.boldSystemFont(ofSize: 17)]
        if #available(iOS 15.0, *) {
            navigationController.navigationBar.standardAppearance.configureWithOpaqueBackground()
            navigationController.navigationBar.scrollEdgeAppearance = navigationController.navigationBar.standardAppearance
        } else {
            navigationController.navigationBar.isTranslucent = false
        }
        return navigationController
    }
    
    @objc func didSelectSearch(_ sender: UIBarButtonItem) {
            if searchView == nil {
                searchView = createSearchView()
            }
            (searchView?.topViewController as? FolioReaderSearchView)?.debugMode = readerConfig.enableSearchDebugMode
            (searchView?.topViewController as? FolioReaderSearchView)?.delegate = self
            
            let searchViewController = searchView ?? UIViewController()
            searchViewController.modalPresentationStyle = .fullScreen
            
            if UIDevice.current.userInterfaceIdiom == .phone {
                present(searchViewController, animated: true, completion: nil)
                return
            }
            searchView?.preferredContentSize = CGSize(width: 400, height: 600)
            searchView?.modalPresentationStyle = .popover
            guard let popover = searchView?.popoverPresentationController else {
                return
            }
            popover.permittedArrowDirections = .up
            popover.barButtonItem = sender
            popover.backgroundColor = #colorLiteral(red: 0.137254902, green: 0.3411764706, blue: 0.5882352941, alpha: 1)

            present(searchViewController, animated: true, completion: nil)
        }
    }

// MARK: FolioPageDelegate

extension FolioReaderCenter: FolioReaderPageDelegate {
    // Util
    private func shouldScrollToLastReadByLocalOffset(lastRead: FolioLastRead) -> Bool {
        if (lastRead.pageOffsetX > 0 || lastRead.pageOffsetY > 0),
            self.folioReader.currentFontSize.rawValue == lastRead.fontSize,
            self.readerConfig.scrollDirection.isVertical == lastRead.isVertical,
            UIDevice.current.orientation.isLandscape == lastRead.isLandscape  {
            return true
        }
        return false
    }
    
    private func scrollToLastReadPosition(page: FolioReaderPage, lastRead: FolioLastRead) {
        // should scroll to last offset if user don't change font size, orientation
        // and scroll direction
        if shouldScrollToLastReadByLocalOffset(lastRead: lastRead) {
            let pageOffset = self.readerConfig.isDirection(lastRead.pageOffsetY, lastRead.pageOffsetX, lastRead.pageOffsetY)
            page.scrollPageToOffset(pageOffset, animated: false)
            return
        }
        // then check rangy
        if let position = lastRead.position, !position.isEmpty {
            if let rangyId = lastRead.rangyId {
                page.webView?.js("setLastRead('\(position)')")  { _ in }
                page.scrollTo(rangyId, animated: false, verticalInset: false)
            }
            return
        }
        // otherwise check pageOffsetX, pageOffsetY
        if (lastRead.pageOffsetX > 0 || lastRead.pageOffsetY > 0) {
            let pageOffset = self.readerConfig.isDirection(lastRead.pageOffsetY, lastRead.pageOffsetX, lastRead.pageOffsetY)
            page.scrollPageToOffset(pageOffset, animated: false)
            return
        }
    }
    
    public func pageDidLoad(_ page: FolioReaderPage) {
        if self.readerConfig.loadSavedPositionForCurrentBook {
            if isFirstLoad {
                updateCurrentPage(page)
                isFirstLoad = false
                if let lastRead = FolioLastRead.lastRead(from: self.readerContainer?.rwBook?.id ?? 0),
                    (self.currentPageNumber == lastRead.page + 1) {
                    scrollToLastReadPosition(page: page, lastRead: lastRead)
                }
            } else if (self.isScrolling == false && folioReader.needsRTLChange == true) {
                page.scrollPageToBottom()
            }
        } else if isFirstLoad {
            updateCurrentPage(page)
            isFirstLoad = false
        }

        // Go to fragment if needed
        if let fragmentID = tempFragment, let currentPage = currentPage , fragmentID != "" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                // your code here
                currentPage.scrollTo(fragmentID, animated: true)
                self.tempFragment = nil
            }
        }
        
        // Go to search result if needed
        if let searchResult = tempSearchResult, let currentPage = currentPage {
            currentPage.scrollTo(searchResult: searchResult, animated: true)
            self.tempSearchResult = nil
        }
        
        // Go to anchor if needed
        // Fix RE-763
        if let anchor = tempAnchor, !anchor.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                self.currentPage?.handleAnchor(anchor, avoidBeginningAnchors: false, animated: true)
                self.tempAnchor = nil
            }
        }
        
        if (readerConfig.scrollDirection == .horizontalWithVerticalContent),
            let offsetPoint = self.currentWebViewScrollPositions[page.pageNumber - 1] {
            page.webView?.scrollView.setContentOffset(offsetPoint, animated: false)
        }
        
        // Pass the event to the centers `pageDelegate`
        pageDelegate?.pageDidLoad?(page)
    }
    
    public func pageWillLoad(_ page: FolioReaderPage) {
        // Pass the event to the centers `pageDelegate`
        pageDelegate?.pageWillLoad?(page)
    }
    
    public func pageTap(_ recognizer: UITapGestureRecognizer) {
        // Pass the event to the centers `pageDelegate`
        pageDelegate?.pageTap?(recognizer)
    }
    
}

// MARK: FolioReaderChapterListDelegate

extension FolioReaderCenter: FolioReaderChapterListDelegate {
    
    func chapterList(_ chapterList: FolioReaderChapterList, didSelectRowAtIndexPath indexPath: IndexPath, withTocReference reference: FRTocReference) {
        //IID
        if let bookTitle = book.title {
        NotificationCenter.default.post(name: Notification.Name("GoogleAnalyticsEvent"),
                                        object: nil,
                                        userInfo: ["category" : "Reader-Table-of-Content",
                                                   "action" : "content select",
                                                   "label" : "\(bookTitle)/ \(reference.title ?? "")"])
        }
        guard let item = findPageByResource(reference) else {
            return
        }

        currentPageNumber = item
        changePageWith(indexPath: IndexPath(row: item - 1, section: 0), animated: true)
        tempReference = reference
    }
    
    func chapterList(didDismissedChapterList chapterList: FolioReaderChapterList) {
        updateCurrentPage()
        
        // Move to #fragment
        if let reference = tempReference {
            if let fragmentID = reference.fragmentID, let currentPage = currentPage , fragmentID != "" {
                currentPage.handleAnchor(reference.fragmentID!, avoidBeginningAnchors: true, animated: true)
            }
            tempReference = nil
        }
    }
    
    func getScreenBounds() -> CGRect {
        var bounds = view.frame
        
        if #available(iOS 11.0, *) {
            bounds = view.safeAreaLayoutGuide.layoutFrame
        }
        
        return bounds
    }
    
}


//IID START
extension String {
    static func load(contentsOfFile: String,
                     encoding: String.Encoding = String.Encoding.utf8,
                     config: FolioReaderConfig,
                     completion: @escaping (_ string: String?, _ error: Error?) -> Void) {
        guard let fileDelegate = config.fileDelegate else {
            do {
                let content = try String(contentsOfFile: contentsOfFile, encoding: encoding)
                completion(content, nil)
            } catch {
                completion(nil, error)
            }
            return
        }
        fileDelegate.load(config, url: contentsOfFile, completion: { (content, error) in
            DispatchQueue.main.async {
                completion(content, error)
            }
        })
    }
    
    static func loadSync(contentsOfFile: String,
                         encoding: String.Encoding = String.Encoding.utf8,
                         config: FolioReaderConfig) -> String {
        guard let fileDelegate = config.fileDelegate else {
            do {
                let content = try String(contentsOfFile: contentsOfFile, encoding: encoding)
                return content
            } catch {
                return ""
            }
        }
        return fileDelegate.loadSync(config, url: contentsOfFile)
    }
}
//IID END


extension FolioReaderCenter: FolioReaderSearchViewDelegate {
    func didClearAllSearch(view: FolioReaderSearchView) {
        currentPage?.webView?.js("clearAllSearchResults();")  { _ in }
    }
    
    func searchingDidStart(keyword: String, view: FolioReaderSearchView) {
        delegate?.searchingDidStart?(keyword: keyword, book: book, center: self)
    }
    
    func searchingDidReturn(keyword: String, view: FolioReaderSearchView) {
        delegate?.searchingDidReturn?(keyword: keyword, book: book, center: self)
    }
    
    func didSelectSearchResult(keyword: String, result: FolioSearchResult, section: FolioSearchDBSectionResult, chapterName: String, view: FolioReaderSearchView) {
        self.changePageWith(page: section.pageIndex, searchResult: result)
        delegate?.didSelectSearchResult?(keyword: keyword, book: book, chapterName: chapterName, center: self)
    }
}

extension FolioReaderCenter: FolioReaderHighlightListDelegate {
    func didSelectHighlight(highlight: Highlight) {
        self.changePageWith(page: highlight.page + 1, andFragment: highlight.highlightId ?? "")
        self.delegate?.didSelectHighlight?(highlight: highlight, center: self)
    }
}
