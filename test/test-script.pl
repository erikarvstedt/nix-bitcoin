# To guarantee that each statement can also be executed interactively, we have to
# adhere to a few restrictions that the test framework imposes on interactive
# statements:
#   - Each statement must consist of one line
#   - Variable names are restricted to a few one-letter words like $a

sub assertMatches { my ($cmd, $regexp) = @_; my $out = $machine->succeed($cmd); if ($out !~ /$regexp/) { print "Pattern '${regexp}' not found in '${out}'\n"; die }; }
sub logHasString { my ($unit, $str) = @_; "journalctl -b --output=cat -u ${unit} --grep='${str}'" }
sub getOutput { my ($cmd) = @_; my $out = $machine->succeed($cmd); chomp $out; $out }

# Unit should not have failed since the system is running
sub assertNoFailure { my ($unit) = @_; $machine->fail(logHasString($unit, "Failed with result")) }
sub assertRunning { my ($unit) = @_; $machine->waitForUnit($unit); assertNoFailure($unit) }

### Tests

assertRunning("setup-secrets");
# Unused secrets should be inaccessible
$machine->succeed('[[ $(stat -c "%U:%G %a" /secrets/dummy) = "root:root 440" ]]');

assertRunning("bitcoind");
$machine->waitUntilSucceeds("bitcoin-cli getnetworkinfo");
assertMatches("su operator -c 'bitcoin-cli getnetworkinfo' | jq", '"version"');

assertRunning("electrs");
$machine->waitForOpenPort(4224); # prometeus metrics provider
assertRunning("nginx");
# SSL stratum server via nginx. Only check for open port, no content is served here
# as electrs isn't ready.
$machine->waitForOpenPort(50003);
# Stop electrs from spamming the test log with 'wait for bitcoind sync' messages
$machine->succeed("systemctl stop electrs");

assertRunning("liquidd");
$machine->waitUntilSucceeds("elements-cli getnetworkinfo");
assertMatches "su operator -c 'elements-cli getnetworkinfo' | jq", '"version"';
$machine->succeed("su operator -c 'liquidswap-cli --help'");

assertRunning("clightning");
assertMatches("su operator -c 'lightning-cli getinfo' | jq", '"id"');

assertRunning("spark-wallet");
# Get auth secret
$a = getOutput(q{cat /secrets/spark-wallet-login | grep -ohP '(?<=login=).*'});
$machine->waitForOpenPort(9737);
assertMatches("curl ${a}\@localhost:9737", "Spark");

assertRunning("lightning-charge");
# Get auth secret
$a = getOutput(q{cat /secrets/lightning-charge-env | grep -ohP '(?<=API_TOKEN=).*'});
$machine->waitForOpenPort(9112);
assertMatches("curl api-token:${a}\@localhost:9112/info | jq", '"id"');

assertRunning("nanopos");
$machine->waitForOpenPort(9116);
assertMatches("curl localhost:9116", "tshirt");

assertRunning("onion-chef");

# FIXME: use 'waitForUnit' because 'create-web-index' always fails during startup due
# to incomplete unit dependencies.
# 'create-web-index' implicitly tests 'nodeinfo'.
$machine->waitForUnit("create-web-index");
$machine->waitForOpenPort(80);
assertMatches("curl localhost", "nix-bitcoin");
assertMatches("curl -L localhost/store", "tshirt");

$machine->waitUntilSucceeds(logHasString("bitcoind-import-banlist", "Importing node banlist"));
assertNoFailure("bitcoind-import-banlist");

### Additional tests

# Get current time in µs
$a = getOutput('date +%s.%6N');

# Sanity-check system by restarting all services
$machine->succeed("systemctl restart bitcoind clightning spark-wallet lightning-charge nanopos liquidd");

# Now that the bitcoind restart triggered a banlist import restart, check that
# re-importing already banned addresses works
$machine->waitUntilSucceeds(logHasString("bitcoind-import-banlist --since=\@${a}", "Importing node banlist"));
assertNoFailure("bitcoind-import-banlist");

### Test lnd

$machine->succeed("systemctl stop nanopos lightning-charge spark-wallet clightning");
$machine->succeed("systemctl start lnd");
assertMatches("su operator -c 'lncli getinfo' | jq", '"version"');
assertNoFailure("lnd");
