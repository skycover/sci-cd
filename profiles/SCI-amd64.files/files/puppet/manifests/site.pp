import "common", "bind9", "approx", "nodes.pp"


stage {pre0: before => Stage[main]}
stage {pre1: before => Stage[main], require => Stage[pre0]}
stage {pre2: before => Stage[main], require => Stage[pre1]}
stage {post0: require => Stage[main]}
stage {post1: require => Stage[post0]}
stage {post2: require => Stage[post1]}

