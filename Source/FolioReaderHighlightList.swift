//
//  FolioReaderHighlightList.swift
//  FolioReaderKit
//
//  Created by Heberti Almeida on 01/09/15.
//  Copyright (c) 2015 Folio Reader. All rights reserved.
//

import UIKit

@objc protocol FolioReaderHighlightListDelegate: class {
    @objc optional func didSelectHighlight(highlight: Highlight)
}

class FolioReaderHighlightList: UITableViewController {

    fileprivate var highlights = [Highlight]()
    fileprivate var readerConfig: FolioReaderConfig
    fileprivate var folioReader: FolioReader
    weak var delegate: FolioReaderHighlightListDelegate?

    init(folioReader: FolioReader, readerConfig: FolioReaderConfig) {
        self.readerConfig = readerConfig
        self.folioReader = folioReader

        super.init(style: UITableViewStyle.plain)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init with coder not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: kReuseCellIdentifier)
        self.tableView.separatorInset = UIEdgeInsets.zero
        self.tableView.backgroundColor = self.folioReader.isNight(self.readerConfig.nightModeMenuBackground, self.readerConfig.menuBackgroundColor)
        self.tableView.separatorColor = self.folioReader.isNight(self.readerConfig.nightModeSeparatorColor, self.readerConfig.menuSeparatorColor)

        guard let bookId = (self.folioReader.readerContainer?.book.name as NSString?)?.deletingPathExtension else {
            self.highlights = []
            return
        }

        self.highlights = Highlight.allByBookId(withConfiguration: self.readerConfig, bookId: bookId, sortBy: "date", ascending: false)
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return highlights.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: kReuseCellIdentifier, for: indexPath)
        cell.backgroundColor = UIColor.clear

        let highlight = highlights[indexPath.row]

        // Format date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = self.readerConfig.localizedHighlightsDateFormat
        let dateString = dateFormatter.string(from: highlight.date ?? Date())

        // Date
        var dateLabel: UILabel!
        if cell.contentView.viewWithTag(456) == nil {
            dateLabel = UILabel(frame: CGRect(x: 0, y: 0, width: view.frame.width-40, height: 16))
            dateLabel.tag = 456
            dateLabel.autoresizingMask = UIViewAutoresizing.flexibleWidth
            dateLabel.font = UIFont(name: "Avenir-Medium", size: 12)
            cell.contentView.addSubview(dateLabel)
        } else {
            dateLabel = cell.contentView.viewWithTag(456) as? UILabel
        }

        dateLabel.text = dateString.uppercased()
        dateLabel.textColor = self.folioReader.isNight(UIColor(white: 5, alpha: 0.3), UIColor.lightGray)
        dateLabel.frame = CGRect(x: 20, y: 20, width: view.frame.width-40, height: dateLabel.frame.height)

        // Text
        let cleanString = highlight.content?.stripHtml().truncate(250, trailing: "...").stripLineBreaks()
        let text = NSMutableAttributedString(string: cleanString ?? "")
        let range = NSRange(location: 0, length: text.length)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 3
        let textColor = self.folioReader.isNight(self.readerConfig.menuTextColor, UIColor.black)

        text.addAttribute(NSAttributedStringKey.paragraphStyle, value: paragraph, range: range)
        text.addAttribute(NSAttributedStringKey.font, value: UIFont(name: "Avenir-Light", size: 16)!, range: range)
        text.addAttribute(NSAttributedStringKey.foregroundColor, value: textColor, range: range)

        if (highlight.type == HighlightStyle.underline.rawValue) {
            text.addAttribute(NSAttributedStringKey.backgroundColor, value: UIColor.clear, range: range)
            text.addAttribute(NSAttributedStringKey.underlineColor, value: HighlightStyle.colorForStyle(highlight.type, nightMode: self.folioReader.nightMode), range: range)
            text.addAttribute(NSAttributedStringKey.underlineStyle, value: NSNumber(value: NSUnderlineStyle.styleSingle.rawValue as Int), range: range)
        } else {
            text.addAttribute(NSAttributedStringKey.backgroundColor, value: HighlightStyle.colorForStyle(highlight.type, nightMode: self.folioReader.nightMode), range: range)
        }

        // Text
        var highlightLabel: UILabel!
        if cell.contentView.viewWithTag(123) == nil {
            highlightLabel = UILabel(frame: CGRect(x: 0, y: 0, width: view.frame.width-40, height: 0))
            highlightLabel.tag = 123
            highlightLabel.autoresizingMask = UIViewAutoresizing.flexibleWidth
            highlightLabel.numberOfLines = 0
            highlightLabel.textColor = UIColor.black
            cell.contentView.addSubview(highlightLabel)
        } else {
            highlightLabel = cell.contentView.viewWithTag(123) as? UILabel
        }

        highlightLabel.attributedText = text
        highlightLabel.sizeToFit()
        highlightLabel.frame = CGRect(x: 20, y: 46, width: view.frame.width-40, height: highlightLabel.frame.height)
        
        // Note text if it exists
        if let note = highlight.noteForHighlight {
            var noteLabel: UILabel!
            if cell.contentView.viewWithTag(789) == nil {
                noteLabel = UILabel(frame: CGRect(x: 0, y: 0, width: view.frame.width-40, height: 0))
                noteLabel.tag = 789
                noteLabel.font = UIFont.systemFont(ofSize: 14)
                noteLabel.autoresizingMask = UIViewAutoresizing.flexibleWidth
                noteLabel.numberOfLines = 3
                noteLabel.textColor = UIColor.gray
                cell.contentView.addSubview(noteLabel)
            } else {
                noteLabel = cell.contentView.viewWithTag(789) as? UILabel
            }
            
            noteLabel.text = note
            noteLabel.sizeToFit()
            noteLabel.frame = CGRect(x: 20, y: 46 + highlightLabel.frame.height + 10, width: view.frame.width-40, height: noteLabel.frame.height)
        } else {
            cell.contentView.viewWithTag(789)?.removeFromSuperview()
        }

        cell.layoutMargins = UIEdgeInsets.zero
        cell.preservesSuperviewLayoutMargins = false
        
        return cell
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let highlight = highlights[indexPath.row]

        let cleanString = highlight.content?.stripHtml().truncate(250, trailing: "...").stripLineBreaks()
        let text = NSMutableAttributedString(string: cleanString ?? "")
        let range = NSRange(location: 0, length: text.length)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 3
        text.addAttribute(NSAttributedStringKey.paragraphStyle, value: paragraph, range: range)
        text.addAttribute(NSAttributedStringKey.font, value: UIFont(name: "Avenir-Light", size: 16)!, range: range)

        let s = text.boundingRect(with: CGSize(width: view.frame.width-40, height: CGFloat.greatestFiniteMagnitude),
                                  options: [NSStringDrawingOptions.usesLineFragmentOrigin, NSStringDrawingOptions.usesFontLeading],
                                  context: nil)

        var totalHeight = s.size.height + 66
        
        if let note = highlight.noteForHighlight {
            let noteLabel = UILabel()
            noteLabel.frame = CGRect(x: 20, y: 46 , width: view.frame.width-40, height: CGFloat.greatestFiniteMagnitude)
            noteLabel.text = note
            noteLabel.lineBreakMode = NSLineBreakMode.byWordWrapping
            noteLabel.numberOfLines = 0
            noteLabel.font = UIFont.systemFont(ofSize: 14)
            
            noteLabel.sizeToFit()
            totalHeight += noteLabel.frame.height
        }

        return totalHeight
    }

    // MARK: - Table view delegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let highlight = highlights[safe: indexPath.row] else { return }
        self.delegate?.didSelectHighlight?(highlight: highlight)
        self.dismiss()
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            guard let highlight = highlights[safe: indexPath.row] else { return }

            if (highlight.page + 1 == self.folioReader.readerCenter?.currentPageNumber),
                let page = self.folioReader.readerCenter?.currentPage {
                Highlight.removeFromHTMLById(withinPage: page, highlightId: highlight.highlightId ?? "") // Remove from HTML
            }

            highlight.remove(withConfiguration: self.readerConfig) // Remove from Database
            highlights.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .fade)
        }
    }
    
    
    // MARK: - Handle rotation transition
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        tableView.reloadData()
    }
}
