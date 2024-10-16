//
//  Bridge.js
//  FolioReaderKit
//
//  Created by Heberti Almeida on 06/05/15.
//  Copyright (c) 2015 Folio Reader. All rights reserved.
//

var newHighlights;
var audioMarkClass;
var wordsPerMinute = 180;
var highlighter;


window.onload = setupRangy;

if (window.addEventListener) {
    window.addEventListener('load', setupRangy, false);
}

function setupRangy() {
    //Normal code goes here
    rangy.init();
    highlighter = rangy.createHighlighter();
    highlighter.addClassApplier(rangy.createClassApplier("highlight-yellow", {
                                                         ignoreWhiteSpace: true,
                                                         tagNames: ["span", "a"],
                                                         elementProperties: {
                                                             href: "#",
                                                             onclick: function() {
                                                             newHighlights = [ highlighter.getHighlightForElement(this) ];
                                                             callHighlightURL(this)
                                                             return false;
                                                         }
                                                         }
                                                         }));
    
    highlighter.addClassApplier(rangy.createClassApplier("highlight-green", {
                                                         ignoreWhiteSpace: true,
                                                         tagNames: ["span", "a"],
                                                         elementProperties: {
                                                             href: "#",
                                                             onclick: function() {
                                                             newHighlights = [ highlighter.getHighlightForElement(this) ];
                                                             callHighlightURL(this)
                                                             return false;
                                                         }
                                                         }
                                                         }));
    
    highlighter.addClassApplier(rangy.createClassApplier("highlight-blue", {
                                                         ignoreWhiteSpace: true,
                                                         tagNames: ["span", "a"],
                                                         elementProperties: {
                                                             href: "#",
                                                             onclick: function() {
                                                             newHighlights = [ highlighter.getHighlightForElement(this) ];
                                                             callHighlightURL(this)
                                                             return false;
                                                         }
                                                         }
                                                         }));
    
    highlighter.addClassApplier(rangy.createClassApplier("highlight-pink", {
                                                         ignoreWhiteSpace: true,
                                                         tagNames: ["span", "a"],
                                                         elementProperties: {
                                                             href: "#",
                                                             onclick: function() {
                                                             newHighlights = [ highlighter.getHighlightForElement(this) ];
                                                             callHighlightURL(this)
                                                             return false;
                                                         }
                                                         }
                                                         }));
    
    highlighter.addClassApplier(rangy.createClassApplier("highlight-underline", {
                                                         ignoreWhiteSpace: true,
                                                         tagNames: ["span", "a"],
                                                         elementProperties: {
                                                             href: "#",
                                                             onclick: function() {
                                                             newHighlights = [ highlighter.getHighlightForElement(this) ];
                                                             callHighlightURL(this)
                                                             return false;
                                                         }
                                                         }
                                                         }));
    
    highlighter.addClassApplier(rangy.createClassApplier("last-read", {
                                                         ignoreWhiteSpace: true,
                                                         tagNames: ["span", "a"],
                                                         elementProperties: {
                                                             href: "#",
                                                             onclick: function() {
                                                         }
                                                         }
                                                         }));
    
};




document.addEventListener("DOMContentLoaded", function(event) {
//    var lnk = document.getElementsByClassName("lnk");
//    for (var i=0; i<lnk.length; i++) {
//        lnk[i].setAttribute("onclick","return callVerseURL(this);");
//    }
});

// Generate a GUID
function guid() {
    function s4() {
        return Math.floor((1 + Math.random()) * 0x10000)
    }
    var guid = s4() + s4() + s4() + s4();
    return "" + guid
}

// Get All HTML
function getHTML() {
    return document.documentElement.outerHTML;
}

// Get HTML Body
function getHTMLBody() {
    return document.body.outerHTML;
}

// Class manipulation
function hasClass(ele,cls) {
  return !!ele.className.match(new RegExp('(\\s|^)'+cls+'(\\s|$)'));
}

function addClass(ele,cls) {
  if (!hasClass(ele,cls)) ele.className += " "+cls;
}

function removeClass(ele,cls) {
  if (hasClass(ele,cls)) {
    var reg = new RegExp('(\\s|^)'+cls+'(\\s|$)');
    ele.className=ele.className.replace(reg,' ');
  }
}

// Font name class
function setFontName(cls) {
    var elm = document.documentElement;
    removeClass(elm, "andada");
    removeClass(elm, "lato");
    removeClass(elm, "lora");
    removeClass(elm, "raleway");
    addClass(elm, cls);
}

// Toggle night mode
function nightMode(enable) {
    var elm = document.documentElement;
    if(enable) {
        addClass(elm, "nightMode");
    } else {
        removeClass(elm, "nightMode");
    }
}

// Set font size
function setFontSize(cls) {
    var elm = document.documentElement;
    removeClass(elm, "textSizeOne");
    removeClass(elm, "textSizeTwo");
    removeClass(elm, "textSizeThree");
    removeClass(elm, "textSizeFour");
    removeClass(elm, "textSizeFive");
    addClass(elm, cls);
}

/*
 *	Native bridge Highlight text
 */
function highlightString(style, bookId, pageIndex) {
    
    var highlightSelection = highlighter.highlightSelection(style);
    newHighlights = highlightSelection;
    var aNewHighlight = newHighlights[0];
    
    var range = window.getSelection().getRangeAt(0);
    var startOffset = range.startOffset;
    var endOffset = range.endOffset;
    var id = bookId + "_" + pageIndex.toString() + "_" + aNewHighlight.characterRange.start.toString() + "_" + aNewHighlight.characterRange.end.toString()
    aNewHighlight.id = id
    var text = window.getSelection().toString();
    var params = [];
    params.push({id: id , rect: getRectForSelectedText(range) , startOffset: startOffset.toString(), endOffset: endOffset.toString(), content: text, rangy: highlighter.serialize() ,color: style});
    clearSelection();
    return JSON.stringify(params);
}

function getHighlightSerialization(style) {
    var serialized = highlighter.serializeSelection(style);
    var parts = [
                 serialized[0].start,
                 serialized[0].end,
                 guid(),
                 style
                 ];
    var params = [];
    params.push({ rangy: parts.join("$") });
    clearSelection();
    return JSON.stringify(params);
}


// Deprecated
function highlightStringWithNote(style) {
    var range = window.getSelection().getRangeAt(0);
    var startOffset = range.startOffset;
    var endOffset = range.endOffset;
    var selectionContents = range.extractContents();
    var elm = document.createElement("highlight");
    var id = guid();
    
    elm.appendChild(selectionContents);
    elm.setAttribute("id", id);
    elm.setAttribute("onclick","callHighlightWithNoteURL(this);");
    elm.setAttribute("class", style);
    
    range.insertNode(elm);
    thisHighlight = elm;
    
    var params = [];
    params.push({id: id, rect: getRectForSelectedText(elm), startOffset: startOffset.toString(), endOffset: endOffset.toString()});
    
    return JSON.stringify(params);
}

// IID added

function setHighlight( serializedHighlight ) {
    highlighter.deserialize(serializedHighlight);
}

function setLastRead( serializedLastRead ) {
    highlighter.deserialize(serializedLastRead);
}

function getHighlights() {
    try {
        return highlighter.serialize();
    } catch(err){}
}

function currentHighlightId() {
    try {
        return newHighlights[0].id;
    } catch(err){}
}

function clearSelection() {
    if (window.getSelection) {
        if (window.getSelection().empty) {  // Chrome
            window.getSelection().empty();
        } else if (window.getSelection().removeAllRanges) {  // Firefox
            window.getSelection().removeAllRanges();
        }
    } else if (document.selection) {  // IE?
        document.selection.empty();
    }
}

function migrateStringToRange( fullString, content ) {
    var range = rangy.createRange();
    var searchScopeRange = rangy.createRange();
    if ( searchScopeRange.findText(fullString) ) {
        
        var options = {
        caseSensitive: false,
        wholeWordsOnly: false,
        withinRange: searchScopeRange,
        };
        if ( range.findText(content)) {
            var bookMark = range.getBookmark();
            return JSON.stringify(bookMark);
        }
        else {
            return "{}"
        }
    }
    else {
        return "{}"
    }
}

// Menu colors
function setHighlightStyle(style) {
    // get range of highligt
    var currentId = newHighlights[0].id
    newHighlights = highlighter.highlightCharacterRanges(style,[newHighlights[0].characterRange])
    newHighlights[0].id = currentId
    return currentId;
}

function removeThisHighlight() {
    var id = newHighlights[0].id;
    highlighter.removeHighlights( newHighlights );
    newHighlights = null;
    return id ;
}

function removeHighlightById(hightlightId) {
    var highlight = getHighlightById(hightlightId);
    var id = highlight.id;
    highlighter.removeHighlights( [highlight] );
    return id;
}

function getHighlightContent() {
    return thisHighlight.textContent
}

function getBodyText() {
    return document.body.innerText;
}

// Method that returns only selected text plain
var getSelectedText = function() {
    return window.getSelection().toString();
}

// Method that gets the Rect of current selected text
// and returns in a JSON format
var getRectForSelectedText = function(elm) {
    if (typeof elm === "undefined") elm = window.getSelection().getRangeAt(0);
    
    var rect = elm.getBoundingClientRect();
    return "{{" + rect.left + "," + rect.top + "}, {" + rect.width + "," + rect.height + "}}";
}

// Method that call that a hightlight was clicked
// with URL scheme and rect informations
var callHighlightURL = function(elm) {
	event.stopPropagation();
	var URLBase = "highlight://";
    var currentHighlightRect = getRectForSelectedText(elm);
   // thisHighlight = elm;
    
    window.location = URLBase + encodeURIComponent(currentHighlightRect);
}

// Method that call that a hightlight with note was clicked
// with URL scheme and rect informations
var callHighlightWithNoteURL = function(elm) {
    event.stopPropagation();
    var URLBase = "highlight-with-note://";
    var currentHighlightRect = getRectForSelectedText(elm);
    thisHighlight = elm;
    
    window.location = URLBase + encodeURIComponent(currentHighlightRect);
}

// Reading time
function getReadingTime() {
    var text = document.body.innerText;
    var totalWords = text.trim().split(/\s+/g).length;
    var wordsPerSecond = wordsPerMinute / 60; //define words per second based on words per minute
    var totalReadingTimeSeconds = totalWords / wordsPerSecond; //define total reading time in seconds
    var readingTimeMinutes = Math.round(totalReadingTimeSeconds / 60);

    return readingTimeMinutes;
}
// IID
var getHighlightOffset = function(highlightId, horizontal) {
    var elem = getHighlightElementById(highlightId);
    return getOffsetOfElement(elem, horizontal);
}
var getHighlightById = function (highlightId) {
    var highlight;
    for ( var i in highlighter.highlights ) {
        var aHighlight = highlighter.highlights[i];
        if (highlightId === aHighlight.id) {
            highlight = aHighlight;
        }
    }
    return highlight;
}
var getHighlightElementById = function (highlightId) {
   
    var highlight = getHighlightById(highlightId)
    var elements = highlight.getHighlightElements();
    elem = elements[0];
    return elem
}

// IID END

/**
 Get Vertical or Horizontal paged #anchor offset
 */
var getAnchorOffset = function(target, horizontal) {
    var elem = document.getElementById(target);
    
    if (!elem) {
        elem = document.getElementsByName(target)[0];
    }
    
    if (horizontal) {
        return document.body.clientWidth * Math.floor(elem.offsetTop / window.innerHeight);
    }
    
    return elem.offsetTop;
}

function findElementWithID(node) {
    if( !node || node.tagName == "BODY")
        return null
    else if( node.id )
        return node
    else
        return findElementWithID(node)
}

function findElementWithIDInView() {

    if(audioMarkClass) {
        // attempt to find an existing "audio mark"
        var el = document.querySelector("."+audioMarkClass)

        // if that existing audio mark exists and is in view, use it
        if( el && el.offsetTop > document.body.scrollTop && el.offsetTop < (window.innerHeight + document.body.scrollTop))
            return el
    }

    // @NOTE: is `span` too limiting?
    var els = document.querySelectorAll("span[id]")

    for(indx in els) {
        var element = els[indx];

        // Horizontal scroll
        if (document.body.scrollTop == 0) {
            var elLeft = document.body.clientWidth * Math.floor(element.offsetTop / window.innerHeight);
            // document.body.scrollLeft = elLeft;

            if (elLeft == document.body.scrollLeft) {
                return element;
            }

        // Vertical
        } else if(element.offsetTop > document.body.scrollTop) {
            return element;
        }
    }

    return null
}


/**
 Play Audio - called by native UIMenuController when a user selects a bit of text and presses "play"
 */
function playAudio() {
    var sel = getSelection();
    var node = null;

    // user selected text? start playing from the selected node
    if (sel.toString() != "") {
        node = sel.anchorNode ? findElementWithID(sel.anchorNode.parentNode) : null;

    // find the first ID'd element that is within view (it will
    } else {
        node = findElementWithIDInView()
    }

    playAudioFragmentID(node ? node.id : null)
}


/**
 Play Audio Fragment ID - tells page controller to begin playing audio from the following ID
 */
function playAudioFragmentID(fragmentID) {
    var URLBase = "play-audio://";
    window.location = URLBase + (fragmentID?encodeURIComponent(fragmentID):"")
}

/**
 Go To Element - scrolls the webview to the requested element
 */
function goToEl(el) {
    var top = document.body.scrollTop;
    var elTop = el.offsetTop - 20;
    var bottom = window.innerHeight + document.body.scrollTop;
    var elBottom = el.offsetHeight + el.offsetTop + 60

    if(elBottom > bottom || elTop < top) {
        document.body.scrollTop = el.offsetTop - 20
    }
    
    /* Set scroll left in case horz scroll is activated.
    
        The following works because el.offsetTop accounts for each page turned
        as if the document was scrolling vertical. We then divide by the window
        height to figure out what page the element should appear on and set scroll left
        to scroll to that page.
    */
    if( document.body.scrollTop == 0 ){
        var elLeft = document.body.clientWidth * Math.floor(el.offsetTop / window.innerHeight);
        document.body.scrollLeft = elLeft;
    }

    return el;
}

/**
 Remove All Classes - removes the given class from all elements in the DOM
 */
function removeAllClasses(className) {
    var els = document.body.getElementsByClassName(className)
    if( els.length > 0 )
    for( i = 0; i <= els.length; i++) {
        els[i].classList.remove(className);
    }
}

/**
 Audio Mark ID - marks an element with an ID with the given class and scrolls to it
 */
function audioMarkID(className, id) {
    if (audioMarkClass)
        removeAllClasses(audioMarkClass);

    audioMarkClass = className
    var el = document.getElementById(id);

    goToEl(el);
    el.classList.add(className)
}

function setMediaOverlayStyle(style){
    document.documentElement.classList.remove("mediaOverlayStyle0", "mediaOverlayStyle1", "mediaOverlayStyle2")
    document.documentElement.classList.add(style)
}

function setMediaOverlayStyleColors(color, colorHighlight) {
    var stylesheet = document.styleSheets[document.styleSheets.length-1];
    stylesheet.insertRule(".mediaOverlayStyle0 span.epub-media-overlay-playing { background: "+colorHighlight+" !important }")
    stylesheet.insertRule(".mediaOverlayStyle1 span.epub-media-overlay-playing { border-color: "+color+" !important }")
    stylesheet.insertRule(".mediaOverlayStyle2 span.epub-media-overlay-playing { color: "+color+" !important }")
}

var currentIndex = -1;


function findSentenceWithIDInView(els) {
    // @NOTE: is `span` too limiting?
    for(indx in els) {
        var element = els[indx];

        // Horizontal scroll
        if (document.body.scrollTop == 0) {
            var elLeft = document.body.clientWidth * Math.floor(element.offsetTop / window.innerHeight);
            // document.body.scrollLeft = elLeft;

            if (elLeft == document.body.scrollLeft) {
                currentIndex = indx;
                return element;
            }

        // Vertical
        } else if(element.offsetTop > document.body.scrollTop) {
            currentIndex = indx;
            return element;
        }
    }
    
    return null
}

function findNextSentenceInArray(els) {
    if(currentIndex >= 0) {
        currentIndex ++;
        return els[currentIndex];
    }
    
    return null
}

function resetCurrentSentenceIndex() {
    currentIndex = -1;
}

function getSentenceWithIndex(className) {
    var sentence;
    var sel = getSelection();
    var node = null;
    var elements = document.querySelectorAll("span.sentence");

    // Check for a selected text, if found start reading from it
    if (sel.toString() != "") {
        console.log(sel.anchorNode.parentNode);
        node = sel.anchorNode.parentNode;

        if (node.className == "sentence") {
            sentence = node

            for(var i = 0, len = elements.length; i < len; i++) {
                if (elements[i] === sentence) {
                    currentIndex = i;
                    break;
                }
            }
        } else {
            sentence = findSentenceWithIDInView(elements);
        }
    } else if (currentIndex < 0) {
        sentence = findSentenceWithIDInView(elements);
    } else {
        sentence = findNextSentenceInArray(elements);
    }

    var text = sentence.innerText || sentence.textContent;
    
    goToEl(sentence);
    
    if (audioMarkClass){
        removeAllClasses(audioMarkClass);
    }
    
    audioMarkClass = className;
    sentence.classList.add(className)
    return text;
}

function wrappingSentencesWithinPTags(){
    currentIndex = -1;
    "use strict";
    
    var rxOpen = new RegExp("<[^\\/].+?>"),
    rxClose = new RegExp("<\\/.+?>"),
    rxSupStart = new RegExp("^<sup\\b[^>]*>"),
    rxSupEnd = new RegExp("<\/sup>"),
    sentenceEnd = [],
    rxIndex;
    
    sentenceEnd.push(new RegExp("[^\\d][\\.!\\?]+"));
    sentenceEnd.push(new RegExp("(?=([^\\\"]*\\\"[^\\\"]*\\\")*[^\\\"]*?$)"));
    sentenceEnd.push(new RegExp("(?![^\\(]*?\\))"));
    sentenceEnd.push(new RegExp("(?![^\\[]*?\\])"));
    sentenceEnd.push(new RegExp("(?![^\\{]*?\\})"));
    sentenceEnd.push(new RegExp("(?![^\\|]*?\\|)"));
    sentenceEnd.push(new RegExp("(?![^\\\\]*?\\\\)"));
    //sentenceEnd.push(new RegExp("(?![^\\/.]*\\/)")); // all could be a problem, but this one is problematic
    
    rxIndex = new RegExp(sentenceEnd.reduce(function (previousValue, currentValue) {
                                            return previousValue + currentValue.source;
                                            }, ""));
    
    function indexSentenceEnd(html) {
        var index = html.search(rxIndex);
        
        if (index !== -1) {
            index += html.match(rxIndex)[0].length - 1;
        }
        
        return index;
    }

    function pushSpan(array, className, string, classNameOpt) {
        if (!string.match('[a-zA-Z0-9]+')) {
            array.push(string);
        } else {
            array.push('<span class="' + className + '">' + string + '</span>');
        }
    }
    
    function addSupToPrevious(html, array) {
        var sup = html.search(rxSupStart),
        end = 0,
        last;
        
        if (sup !== -1) {
            end = html.search(rxSupEnd);
            if (end !== -1) {
                last = array.pop();
                end = end + 6;
                array.push(last.slice(0, -7) + html.slice(0, end) + last.slice(-7));
            }
        }
        
        return html.slice(end);
    }
    
    function paragraphIsSentence(html, array) {
        var index = indexSentenceEnd(html);
        
        if (index === -1 || index === html.length) {
            pushSpan(array, "sentence", html, "paragraphIsSentence");
            html = "";
        }
        
        return html;
    }
    
    function paragraphNoMarkup(html, array) {
        var open = html.search(rxOpen),
        index = 0;
        
        if (open === -1) {
            index = indexSentenceEnd(html);
            if (index === -1) {
                index = html.length;
            }
            
            pushSpan(array, "sentence", html.slice(0, index += 1), "paragraphNoMarkup");
        }
        
        return html.slice(index);
    }
    
    function sentenceUncontained(html, array) {
        var open = html.search(rxOpen),
        index = 0,
        close;
        
        if (open !== -1) {
            index = indexSentenceEnd(html);
            if (index === -1) {
                index = html.length;
            }
            
            close = html.search(rxClose);
            if (index < open || index > close) {
                pushSpan(array, "sentence", html.slice(0, index += 1), "sentenceUncontained");
            } else {
                index = 0;
            }
        }
        
        return html.slice(index);
    }
    
    function sentenceContained(html, array) {
        var open = html.search(rxOpen),
        index = 0,
        close,
        count;
        
        if (open !== -1) {
            index = indexSentenceEnd(html);
            if (index === -1) {
                index = html.length;
            }
            
            close = html.search(rxClose);
            if (index > open && index < close) {
                count = html.match(rxClose)[0].length;
                pushSpan(array, "sentence", html.slice(0, close + count), "sentenceContained");
                index = close + count;
            } else {
                index = 0;
            }
        }
        
        return html.slice(index);
    }
    
    function anythingElse(html, array) {
        pushSpan(array, "sentence", html, "anythingElse");
        
        return "";
    }
    
    function guessSenetences() {
        var paragraphs = document.getElementsByTagName("p");

        Array.prototype.forEach.call(paragraphs, function (paragraph) {
            var html = paragraph.innerHTML,
                length = html.length,
                array = [],
                safety = 100;

            while (length && safety) {
                html = addSupToPrevious(html, array);
                if (html.length === length) {
                    if (html.length === length) {
                        html = paragraphIsSentence(html, array);
                        if (html.length === length) {
                            html = paragraphNoMarkup(html, array);
                            if (html.length === length) {
                                html = sentenceUncontained(html, array);
                                if (html.length === length) {
                                    html = sentenceContained(html, array);
                                    if (html.length === length) {
                                        html = anythingElse(html, array);
                                    }
                                }
                            }
                        }
                    }
                }

                length = html.length;
                safety -= 1;
            }

            paragraph.innerHTML = array.join("");
        });
    }
    
    guessSenetences();
}

// Class based onClick listener

function addClassBasedOnClickListener(schemeName, querySelector, attributeName, selectAll) {
	if (selectAll) {
		// Get all elements with the given query selector
		var elements = document.querySelectorAll(querySelector);
		for (elementIndex = 0; elementIndex < elements.length; elementIndex++) {
			var element = elements[elementIndex];
			addClassBasedOnClickListenerToElement(element, schemeName, attributeName);
		}
	} else {
		// Get the first element with the given query selector
		var element = document.querySelector(querySelector);
		addClassBasedOnClickListenerToElement(element, schemeName, attributeName);
	}
}

function addClassBasedOnClickListenerToElement(element, schemeName, attributeName) {
	// Get the content from the given attribute name
	var attributeContent = element.getAttribute(attributeName);
	// Add the on click logic
	element.setAttribute("onclick", "onClassBasedListenerClick(\"" + schemeName + "\", \"" + encodeURIComponent(attributeContent) + "\");");
}

var onClassBasedListenerClick = function(schemeName, attributeContent) {
	// Prevent the browser from performing the default on click behavior
	event.preventDefault();
	// Don't pass the click event to other elemtents
	event.stopPropagation();
	// Create parameters containing the click position inside the web view.
	var positionParameterString = "/clientX=" + event.clientX + "&clientY=" + event.clientY;
	// Set the custom link URL to the event
	window.location = schemeName + "://" + attributeContent + positionParameterString;
}

function createSelectionFromPoint(startX, startY, endX, endY) {
    var doc = document;
    var start, end, range = null;
    if (typeof doc.caretPositionFromPoint != "undefined") {
        start = doc.caretPositionFromPoint(startX, startY);
        end = doc.caretPositionFromPoint(endX, endY);
        range = doc.createRange();
        range.setStart(start.offsetNode, start.offset);
        range.setEnd(end.offsetNode, end.offset);
    } else if (typeof doc.caretRangeFromPoint != "undefined") {
        start = doc.caretRangeFromPoint(startX, startY);
        //end = doc.caretRangeFromPoint(endX, endY);
        range = doc.createRange();
        range.setStart(start.startContainer, start.startOffset);
        //range.setEnd(end.startContainer, end.startOffset);
        range.setEndAfter(start.endContainer);
    }
    if (range !== null && typeof window.getSelection != "undefined") {
        var sel = window.getSelection();
        sel.removeAllRanges();
        sel.addRange(range);
    } else if (typeof doc.body.createTextRange != "undefined") {
        range = doc.body.createTextRange();
        range.moveToPoint(startX, startY);
        var endRange = range.duplicate();
        endRange.moveToPoint(endX, endY);
        range.setEndPoint("EndToEnd", endRange);
        range.select();
    }
}

var searchResults = [];
var lastSearchQuery = null;
var testCounter = 0;
var searchResultsInvisible = true;

// Testing purpose calls
function test() {
    
    ++testCounter;
    console.log("-> testCounter = " + testCounter);
    
    var searchQuery = "look";
    
    if (testCounter == 1) {
        
        getCompatMode();
        wrappingSentencesWithinPTags();
        
        if (FolioPageFragment.getDirection() == "HORIZONTAL")
            initHorizontalDirection();
        
        highlightSearchResult(searchQuery, 1, true);
        
    } else if (testCounter == 2) {
        
        makeSearchResultsInvisible();
        
    } else if (testCounter == 3) {
        
        highlightSearchResult(searchQuery, 2, true);
        
    } else if (testCounter == 4) {
        
    }
}

function highlightSearchResult(searchQuery, occurrenceInChapter, horizontal) {
    
    if (searchQuery == lastSearchQuery) {
        makeSearchResultsInvisible();
    } else {
        resetSearchResults();
        searchResults = applySearchResultClass(searchQuery);
        console.debug("-> Search Query Found = " + searchResults.length);
    }
    
    return applySearchResultVisibleClass(occurrenceInChapter, horizontal);
}

function applySearchResultClass(searchQuery) {
    
    var searchQueryRegExp = new RegExp(escapeRegExp(searchQuery), "i");
    
    var searchResults = [];
    var searchChildNodesArray = [];
    var elementArray = [];
    var textNodeArray = [];
    
    var bodyElement = document.getElementsByTagName('body')[0];
    var elementsInBody = bodyElement.getElementsByTagName('*');
    
    for (var i = 0 ; i < elementsInBody.length ; i++) {
        
        var childNodes = elementsInBody[i].childNodes;
        
        for (var j = 0; j < childNodes.length; j++) {
            
            if (childNodes[j].nodeType == Node.TEXT_NODE &&
                childNodes[j].nodeValue.trim().length) {
                //console.log("-> " + childNodes[j].nodeValue);
                
                if (childNodes[j].nodeValue.match(searchQueryRegExp)) {
                    //console.log("-> Found -> " + childNodes[j].nodeValue);
                    
                    searchChildNodesArray.push(
                                               getSearchChildNodes(childNodes[j].nodeValue, searchQuery));
                    
                    elementArray.push(elementsInBody[i]);
                    textNodeArray.push(childNodes[j]);
                }
            }
        }
    }
    
    for (var i = 0 ; i < searchChildNodesArray.length ; i++) {
        
        var searchChildNodes = searchChildNodesArray[i];
        
        for (var j = 0 ; j < searchChildNodes.length ; j++) {
            
            if (searchChildNodes[j].className == "search-result")
                searchResults.push(searchChildNodes[j]);
            elementArray[i].insertBefore(searchChildNodes[j], textNodeArray[i]);
        }
        
        elementArray[i].removeChild(textNodeArray[i]);
    }
    
    lastSearchQuery = searchQuery;
    return searchResults;
}

function getSearchChildNodes(text, searchQuery) {
    
    var arrayIndex = [];
    var matchIndexStart = -1;
    var textChunk = "";
    var searchChildNodes = [];
    
    for (var i = 0, j = 0 ; i < text.length ; i++) {
        
        textChunk += text[i];
        
        if (text[i].match(new RegExp(escapeRegExp(searchQuery[j]), "i"))) {
            
            if (matchIndexStart == -1)
                matchIndexStart = i;
            
            if (searchQuery.length == j + 1) {
                
                var textNode = document.createTextNode(
                                                       textChunk.substring(0, textChunk.length - searchQuery.length));
                
                var searchNode = document.createElement("span");
                searchNode.className = "search-result";
                var queryTextNode = document.createTextNode(
                                                            text.substring(matchIndexStart, matchIndexStart + searchQuery.length));
                searchNode.appendChild(queryTextNode);
                
                searchChildNodes.push(textNode);
                searchChildNodes.push(searchNode);
                
                arrayIndex.push(matchIndexStart);
                matchIndexStart = -1;
                j = 0;
                textChunk = "";
                
            } else {
                j++;
            }
            
        } else {
            matchIndexStart = -1;
            j = 0;
        }
    }
    
    if (textChunk !== "") {
        var textNode = document.createTextNode(textChunk);
        searchChildNodes.push(textNode);
    }
    
    return searchChildNodes;
}

function makeSearchResultsVisible() {
    
    for (var i = 0 ; i < searchResults.length ; i++) {
        searchResults[i].className = "search-result-visible";
    }
    searchResultsInvisible = false;
}

var didMark = false;
var sResults = [];
var currentClass = "current";

function checkNoneEscapingChars(str) {
    return str.replace(/\s/g,' ');
}

function markSearchResult(searchQuery, occurrenceInChapter, horizontal) {
    if (didMark) {
        var searchResult = sResults[occurrenceInChapter - 1];
        invisibleSearchResults();
        searchResult.classList.add(currentClass);
        return getOffsetOfElement(searchResult, horizontal);
    }
    new Mark(document.body).mark(searchQuery, {
            'separateWordSearch': false,
            'acrossElements': true
                                 
            });
    var results = document.getElementsByTagName("markJS-inner");
    var ignoresItem = [];
    for (var i = 0 ; i < results.length ; i++) {
        if (ignoresItem.includes(results[i])) {
            continue;
        }
        var s = results[i].textContent;
        if (checkNoneEscapingChars(s.toLowerCase()) == checkNoneEscapingChars(searchQuery.toLowerCase())) {
            sResults.push(results[i]);
        } else {
            for (var j = i + 1 ; j < results.length ; j++) {
                var text = results[j].textContent;
                if ((results[j].textContent.length == 0) && (results[j].textContent.length > 0)) {
                    text = " ";
                }
                s = s + text;
                ignoresItem.push(results[j]);
                if (s.toLowerCase() == searchQuery.toLowerCase()) {
                    sResults.push(results[i]);
                    break;
                }
            }
        }
    }
    didMark = true;
    var searchResult = sResults[occurrenceInChapter - 1];
    return getOffsetOfElement(searchResult, horizontal);
    
}

function invisibleSearchResults() {
    for (var i = 0 ; i < sResults.length ; i++) {
        sResults[i].classList.remove(currentClass);
    }
}

function clearAllSearchResults() {
    new Mark(document.body).unmark();
    didMark = false;
    sResults = [];
}

function makeSearchResultsInvisible() {
    
    if (searchResultsInvisible)
        return;
    for (var i = 0 ; i < searchResults.length ; i++) {
        if (searchResults[i].className == "search-result-visible")
            searchResults[i].className = "search-result-invisible";
    }
    searchResultsInvisible = true;
}

function applySearchResultVisibleClass(occurrenceInChapter, horizontal) {
    
    var searchResult = searchResults[occurrenceInChapter - 1];
    if (searchResult === undefined)
        return;
    searchResult.className = "search-result-visible";
    searchResultsInvisible = false;
    
    return getOffsetOfElement(searchResult, horizontal);
}



function resetSearchResults() {
    
    for (var i = 0 ; i < searchResults.length ; i++) {
        searchResults[i].outerHTML = searchResults[i].innerHTML;
    }
    
    searchResults = [];
    lastSearchQuery = null;
    searchResultsInvisible = true;
}

function escapeRegExp(str) {
    return str.replace(/([.*+?^=!:${}()|\[\]\/\\])/g, "\\$1");
}

function getOffsetOfElement(elem, horizontal) {
    if (isElementBelongToTable(elem)) {
        var offset = offsetOfTDElement(elem)
        if (horizontal) {
            return document.body.clientWidth * Math.floor(offset.top / window.innerHeight);
        }
        return offset.top;
    }
    // normal element
    if (horizontal) {
        return document.body.clientWidth * Math.floor(elem.offsetTop / window.innerHeight);
    }
    return elem.offsetTop;
}

function scrollToElement(element) {
    element.scrollIntoView();
}

function bodyOrHtml() {
    if ('scrollingElement' in document) {
        return document.scrollingElement;
    }
    // Fallback for legacy browsers
    if (navigator.userAgent.indexOf('WebKit') != -1) {
        return document.body;
    }
    return document.documentElement;
}

function scrollToSelection( sel ) {
    var node = document.createElement("span");
    sel.surroundContents(node);
    var scrollDist = node.offsetTop
    - (window.innerHeight+node.offsetHeight)/2;
    if ( scrollDist > 0 )
        window.scrollBy(0,scrollDist);
}

function offsetOfTDElement(elem) {
    if(!elem) elem = this;
    var x = elem.offsetLeft;
    var y = elem.offsetTop;
    while (elem = elem.offsetParent) {
        x += elem.offsetLeft;
        y += elem.offsetTop;
    }
    return { left: x, top: y };
}

function isElementBelongToTable(elem) {
    if (elementIsTableTagName(elem)) {
        return true
    }
    while (elem = elem.parentElement) {
        if (elementIsTableTagName(elem)) {
            return true
        }
    }
    return false
}

function elementIsTableTagName(elem) {
    if ( (elem.tagName.toLowerCase() == "td") ||
         (elem.tagName.toLowerCase() == "tr") ||
         (elem.tagName.toLowerCase() == "thead") ||
         (elem.tagName.toLowerCase() == "tbody") ||
         (elem.tagName.toLowerCase() == "tfoot") )  {
        return true
    }
    return false
}
