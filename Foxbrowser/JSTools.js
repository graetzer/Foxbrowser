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
                link.setAttribute('target','_self');
                link.href = 'newtab:'+escape(link.href);
            }
        }
    }
}

function FoxbrowserModifyOpen() {
    if (!window.FoxbrowserOpen) {
        window.FoxbrowserOpen = window.open;
    }

    window.open = function(url,target,param) {
        if (url && url.length > 0) {
            if (!target) target = "_blank";
            if (target != '_self') {
                location.href = 'newtab:'+escape(url);
            } else {
                window.FoxbrowserOpen(url,target,param);
            }
        }
    }
}