has Vikna::Label $.status;
has Vikna::TextScroll $.reporter;
has $.queue = Channel.new;

method get-page(Str:D $url) {
    $.status.text: $url;                   # A label-like widget
    say "-> $url";
    my @links = self.scrape-url($url);
    say "got ", +@links, " links to process";
    $.reporter.say: "got ", +@links, " links to process";
    $!queue.send($_) for @links;
}

for ^$*KERNEL.cpu-cores -> $i {
    ...
    start react whenever $!queue -> $url {
        @scraper[$i].get-page($url)
    }
}

