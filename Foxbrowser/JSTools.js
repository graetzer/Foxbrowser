function MyAppGetHTMLElementsAtPoint(x,y) {
    var tags = "";
    var e = document.elementFromPoint(x,y);
    while (e) {
        if (e.tagName) {
            var name = e.tagName.toUpperCase();
            if (name == 'A') {
                tags += 'A[' + e.href + ']||';
            } else if (name == 'IMG') {
                tags += 'IMG[' + e.src + ']||';
            }
        }
        e = e.parentNode;
    }
    return tags;
}