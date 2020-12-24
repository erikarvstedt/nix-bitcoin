Tests
---

The internal test suite is useful for testing changes and exploring features.

The following test scenarios are available
* `base`: Basic configuration on which all other tests build
* `default`: Same as secureNode
* `full`: All available tests and services
* `secureNode`: Tests `secure-node.nix` preset
* `netns`: Tests network namespace isolation
* `regtest`: Tests regtest-enabled services
* `netnsRegtest`: `netns` and `regtest` without `secureNode` 
* `hardened`: Tests the nix-bitcoin hardened profile
* `netnsBase`
* `regtestBase`

See [`run-tests.sh`](run-tests.sh) for a complete documentation.
