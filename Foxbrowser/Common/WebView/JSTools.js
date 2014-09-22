function FoxbrowserGetHTMLElementsAtPoint(x,y) {
    var tags = "";
    var e = document.elementFromPoint(x,y);
    while (e) {
        if (e.tagName) {
            var name = e.tagName.toUpperCase();
            if (name == 'A') {
                tags += 'A[' + e.href + ']|&|';
            } else if (name == 'IMG') {
                tags += 'IMG[' + e.src + ']|&|';
            }
        }
        e = e.parentNode;
    }
    return tags;
}

function FoxbrowserModifyLinkTargets() {
    var allLinks = document.getElementsByTagName('a');
    if (allLinks) {
        var i;
        for (i=0; i<allLinks.length; i++) {
            var link = allLinks[i];
            var target = link.getAttribute('target');
            if (target && target == '_blank') {
                //link.setAttribute('target','_self');
                link.onclick = function (e) {
                    var el = e.target;
                    while (el.tagName != 'A' && el.parentNode)
                        el = el.parentNode;
                    
                    if (el.href) {
                        window.location.href = 'newtab:'+escape(el.href);
                        return false;
                    }
                }
            }
        }
    }
}


function FoxbrowserModifyWindow() {
    if (!window.FoxbrowserOpen) {
        window.FoxbrowserOpen = window.open;
    }
    
    window.open = function(url,target,param) {
        if (url && url.length > 0) {
            if (!target) target = '_blank';
            if (target != '_self') {
                location.href = 'newtab:'+escape(url);
            } else {
                window.FoxbrowserOpen(url,target,param);
            }
        }
    }
    
    window.close = function() {
        window.FoxbrowserOpen('closetab://about:blank');
    }
}

FoxbrowserModifyLinkTargets();
FoxbrowserModifyWindow();