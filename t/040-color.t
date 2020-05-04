use v6.e.PREVIEW;
use Test::Async;
use Vikna::Color;
use Vikna::Color::Index;
use Vikna::Color::Named;
use Vikna::Color::RGB;
use Vikna::Color::RGBA;

plan 2, :parallel;

diag "This suite does benchmarking, this might take a while." if $*OUT.t;

subtest "Parsing" => {
    my @clist =
            # RGB of this line depends on the content of resources/color-index.json
            { color => '123', :valid, rgb => (135, 255, 255), type => 'Index', str => "123" },
            { color => '300', :!valid },
            { color => '#abc', :valid, rgb => (0xAA, 0xBB, 0xCC), type => 'RGB' },
            { color => '#aabbcc', :valid, rgb => (0xAA, 0xBB, 0xCC), type => 'RGB' },
            { color => '#aabbccdd', :valid, rgb => (0xAA, 0xBB, 0xCC, 0xDD), type => 'RGBA' },
            { color => '#aabbcecdd', :!valid },
            { color => '#aabccdd', :!valid },
            { color => "green", :valid, rgb => (0, 255, 0), type => 'Named' },
            { color => "nosuchcolor", :!valid },
            { color => "1color", :!valid },
            { color => "darkmagenta", :valid, rgb => (139, 0, 139), type => 'Named' },
            { color => 'rgb:200,12,3', :valid, rgb => (200, 12, 3), type => 'RGB' },
            { color => 'rgb:400,12,3', :!valid },
            { color => 'rgb: .2, .5, .1', :valid, rgb => (51, 128, 26), type => 'RGB' },
            { color => 'rgb: .2, 1.0, .1', :valid, rgb => (51, 255, 26), type => 'RGB' },
            { color => 'rgba: .2, 1.0, .1, .6', :valid, rgb => (51, 255, 26, 153), type => 'RGBA' },
            { color => 'rgba: 100, 150, 200, 128', :valid, rgb => (100, 150, 200, 128), type => 'RGBA' },
            { color => 'rgbd: 1., .3, .1', :valid, rgb => (255, 77, 26), type => 'RGB' },
            { color => 'rgbd: 100, 100, 100', :!valid },
            { color => 'rgb: 100, 100, 100, 100', :!valid },
            { color => 'rgba: 100, 100, 100, 100, 100', :!valid },
            { color => 'rgb: 1, 1., 1', :!valid },
            { color => 'rgb: 1., .3, 1', :!valid },
            { color => '255,120,100', :valid, rgb => (255, 120, 100), type => 'RGB' },
            { color => '.5, .3  , .8', :valid, rgb => (128, 77, 204), type => 'RGB' },
            { color => '.5, 3, .8', :!valid },
            { color => '100,100,0', :valid, rgb => (100, 100, 0), type => 'RGB' },
            { color => "", :!valid },
            { color => "12,13,14 underline", :!valid },
            ;

    plan +@clist, :parallel;

    for @clist -> %ctest {
        subtest 'Color string: "' ~ %ctest<color> ~ '"' => {
            my $c = Vikna::Color.parse(%ctest<color>);
            if %ctest<valid> {
                plan 4;
                ok ?$c, "color string is valid";
                skip-rest "color string failed to parse" unless $c;
                my \expected-role = ::("Vikna::Color::" ~ %ctest<type>);
                # diag "EXPECTED ROLE: " ~ expected-role.^name ~ ", color: " ~ $c.WHICH ~ ", matches: " ~ ($c ~~ expected-role);
                my $method = %ctest<type> eq 'RGBA' ?? 'rgba' !! 'rgb';
                if $c {
                    does-ok $c, expected-role, "color type is " ~ %ctest<type>;
                    is-deeply $c."$method"().List, %ctest<rgb>, "$method triplet";
                    my $expected-str = %ctest<type> ~~ 'RGB' | 'RGBA'
                                        ?? %ctest<rgb>.join(",")
                                        !! %ctest<color>;
                    is ~$c, $expected-str, "parsed color stringifies into '$expected-str'";
                }
            }
            else {
                plan 1;
                nok ?$c, "color string is invalid";
            }
        }
    }
}

subtest "Cache performance" => {
    plan 1;
    my @clist = ("rgb:" ~ ((255.rand).round xx 3).join(",")) xx 100;

    my $parse-loops = 300;
    my @pready = Promise.new xx 2;
    my $pstart = Promise.new;
    my @total = 0 xx 2;
    my @params = (), (:no-cache);

    my @p;
    for ^2 -> $bidx {
        @p.push: start {
            my %params = @params[$bidx];
            @pready[$bidx].keep(True);
            await $pstart;
            for ^$parse-loops {
                for @clist -> $cstr {
                    my $st = now;
                    my $c = Vikna::Color.parse: $cstr, |%params;
                    @total[$bidx] += now - $st;
                }
            }
        }
    }

    await @pready;
    $pstart.keep(True);

    await @p;

    if $*OUT.t {
        diag "Cached parse took " ~ @total[0].fmt("%.2f") ~ " sec";
        diag "Uncached parse took " ~ @total[1].fmt("%.2f") ~ " sec";
    }
    ok @total[0] < @total[1], "cached parsing is faster than non-cached by factor " ~ (@total[1] / @total[0]).fmt("%.2f");
}
