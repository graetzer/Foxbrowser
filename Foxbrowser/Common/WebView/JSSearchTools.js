
// Original JavaScript code by Chirp Internet: www.chirp.com.au
// Please acknowledge use of this code by including this header

function Foxbrowser_Hilitor() {
    var targetNode = document.body;
    var hiliteTag = "EM";
    var skipTags = new RegExp("^(?:" + hiliteTag + "|SCRIPT|FORM|SPAN)$");
    var colors = ["#ff6", "#a0ffff", "#9f9", "#f99", "#f6f"];
    var wordColor = [];
    var colorIdx = 0;
    var matchRegex = "";
	
	var resultCount = 0;
	var currentIndex = 0;
	var htmlIDPrefix = 'Foxbrowser_Hilitor_';
    
    this.setRegex = function(input) {
        input = input.replace(/^[^\w]+|[^\w]+$/g, "").replace(/[^\w'-]+/g, "|");
        matchRegex = new RegExp("\\b(" + input + ")\\b","i");
    }
                                                                
    this.getRegex = function() {
        return matchRegex.toString().replace(/^\/\\b\(|\)\\b\/i$/g, "").replace(/\|/g, " ");
    }

    // recursively apply word highlighting
    this.hiliteWords = function(node) {
        if(node == undefined || !node) return;
        if(!matchRegex) return;
        if(skipTags.test(node.nodeName)) return;

        if(node.hasChildNodes()) {
        	for(var i=0; i < node.childNodes.length; i++)
        		this.hiliteWords(node.childNodes[i]);
        }
        if(node.nodeType == 3) { // NODE_TEXT
	        if((nv = node.nodeValue) && (regs = matchRegex.exec(nv))) {
		        if(!wordColor[regs[0].toLowerCase()]) {
		        	wordColor[regs[0].toLowerCase()] = colors[colorIdx++ % colors.length];
		        }

		        var match = document.createElement(hiliteTag);
		        match.appendChild(document.createTextNode(regs[0]));
		        match.style.backgroundColor = wordColor[regs[0].toLowerCase()];
		        match.style.fontStyle = "inherit";
		        match.style.color = "#000";
				
				match.id  = htmlIDPrefix + resultCount;
				resultCount++;

		        var after = node.splitText(regs.index);
		        after.nodeValue = after.nodeValue.substring(regs[0].length);
		        node.parentNode.insertBefore(match, after);
	        }
        }
    };

    // remove highlighting
    this.remove = function() {
		resultCount = 0;
		currentIndex = 0;
		
        var arr = document.getElementsByTagName(hiliteTag);
        while(arr.length && (el = arr[0])) {
           el.parentNode.replaceChild(el.firstChild, el);
        }
    };

    // start highlighting at target node
    this.apply = function(input) {
        if(input == undefined || !input) return;
        this.remove();
        this.setRegex(input);
		resultCount = 0;
		currentIndex = 0;
        this.hiliteWords(targetNode);
        return resultCount;
    };

	this.showNext = function() {
	    if (currentIndex < resultCount-1) {
			var el = document.getElementById(htmlIDPrefix + currentIndex);
			el.style.border = "";
	        currentIndex++;
			el = document.getElementById(htmlIDPrefix + currentIndex);
			el.style.border = "solid blue 3px";
			
	        window.location.hash = htmlIDPrefix + currentIndex;
	    }
	}
	
	this.showLast = function() {
	    if (currentIndex > 0) {
			var el = document.getElementById(htmlIDPrefix + currentIndex);
			el.style.border = "";
	        currentIndex--;
			el = document.getElementById(htmlIDPrefix + currentIndex);
			el.style.border = "solid blue 3px";
	        
	        window.location.hash = htmlIDPrefix + currentIndex;
	    }
	}
}

var foxbrowser_hilitior_instance = new Foxbrowser_Hilitor();
