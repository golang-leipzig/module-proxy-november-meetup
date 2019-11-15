---
title: Go Module Proxy
subtitle: Internals and Pitfalls
author: Andreas Linz—klingt.net
date: 2019-11-14T19+01:00
---

# A short History { data-background-image=https://images.unsplash.com/photo-1458040937381-49c067dfd49a?ixlib=rb-1.2.1&ixid=eyJhcHBfaWQiOjEyMDd9&auto=format&fit=crop&w=1650&q=80 data-background-opacity=0.31415 }

# `$GOPATH/src`

- **no version management everything was "latest"**

# `GO15VENDOREXPERIMENT=on`

- In mid of 2015 [Go 1.5][go15] introduced experimental `/vendor` support
- `/vendor` supplies manual managed dependencies
- **dependencies need to be part of the repository**
- (nobody likes to work with git submodules, `git clone --recursive ...`)

---

### [Go 2017 Survey Results][go2017survey]:

When asked about the biggest challenges to their own personal use of Go, users clearly conveyed that **lack of dependency management**…

---

### [Go 2018 Survey Results][go2018survey]:

[One of] The top three major challenges we identified are:

**Package management** (e.g., "Keeping up with vendoring", "dependency / packet [sic] management / vendoring not unified")
…

# 🤔 { data-background-video=https://media.giphy.com/media/2H67VmB5UEBmU/giphy.mp4 data-background-video-loop=loop data-background-opacity=0.31415 }

# Era of Package Managers { data-background-image=https://images.unsplash.com/photo-1494412574643-ff11b0a5c1c3?ixlib=rb-1.2.1&ixid=eyJhcHBfaWQiOjEyMDd9&auto=format&fit=crop&w=1650&q=80 data-background-opacity=0.31415 }

---

::: incremental

- godm
- gv
- gom
- Godep
- Glide
- dep 🦥
- …

:::

[list of package managers][packagemanagerlist]

---

- many Go developers were unhappy with package management
- no official solution, only more or less stable third-party package management tools
- you still needed to work inside the `$GOPATH` (or use "clever" hacks)

---

[Dave Cheney][davecheney2016] said in 2016:

In my experience, many newcomers to Go are **frustrated with the single workspace $GOPATH model.**

With the end of 2016 a [default `GOPATH`][defaultgopath] is set (`~/go`).

# GO111MODULES=on { data-background-image=https://images.unsplash.com/photo-1517373116369-9bdb8cdc9f62?ixlib=rb-1.2.1&ixid=eyJhcHBfaWQiOjEyMDd9&auto=format&fit=crop&w=1950&q=80 data-background-opacity=0.31415 }

# What's a Module?

- **module**: collection of related Go packages that are versioned together as single unit
- e.g. a simple webserver using `net/http` from Go 1.1x with `gorilla/mux` as router is a collection of packages
- modules add precise dependency requirements (`go.mod`) → **reproducible builds**
- support will be finalized with Go 1.14

[Modules documentation][modulesdocumentation]

# `vgo`

- mid of 2018 [Go 1.11][go111] introduced experimental support for the new _modules_ format
- `vgo` = `go` tool with modules support
- [vgo was pretty unstable][vgoissue] ([350+ issues](https://github.com/golang/go/issues?utf8=%E2%9C%93&q=is%3Aissue+is%3Aopen+vgo+x%2Fvgo%3A))

# Terminology

- a repository contains one or more modules
- a module contains one or more packages
- package is a single directory of `.go` files

# How to Setup a Modules Project?

---

```sh
$ go mod init github.com/example/project
```

- migrates existing dependency definitions if present (e.g. `Gopkg.toml` from `dep`)
- creates `go.mod` and `go.sum` files

Commit both but never edit them manually!

(`go get` and friends will do this for you)

# Add Dependency in Specific Version

```sh
$ go get github.com/example/project@v1.2.3
```

- the version can be a git reference as well (hash/branch…)

# Go Modules Proxy

- introduced with Go 1.13
- default one is [proxy.golang.org][proxygolang] ([not open-source](https://youtu.be/kqMxaO9d1NM?t=2214))
- package checksums (`go.sum`) are validated against [sum.golang.org][sumdatabase] by default
- Go 1.13 started to [deprecate GOPATH][gomodules2019]

# 🕵️ { data-background-image=https://images.unsplash.com/photo-1461685265823-f8d5d0b08b9b?ixlib=rb-1.2.1&ixid=eyJhcHBfaWQiOjEyMDd9&auto=format&fit=crop&w=2700&q=80 data-background-opacity=0.31415 }

- potential information leak
- set `GOPRIVATE=my.secret.git.com[,…]` for private repositories

# Advantages of Using a Proxy

::: incremental

- faster builds (less stress on the git server)
- persistent depencies (if upstream is down)
- reproducible builds (no `git push -f`)

:::

# Proxy Implementations

- [gocenter.io](https://gocenter.io/) (JFrog, commercial)
- [goproxy.cn](https://goproxy.cn/) (open source, trustworthy!?)
- [Athens](https://github.com/gomods/athens) (open source, most mature project)
- …

# Write ony Yourself?

- learn about modules
- get to know the module proxy API
- **simpler access to private repositories**

# Private Repositories

- `go get` knows nothing about authentication
- common solution HTTPS to SSH rewrite:

```sh
$ git config --global url."git@git.company.com:".insteadOf https://git.company.com/
```

# Module Proxy API

- `go help goproxy`
- only `GET` resources

---

![module proxy protocol](https://blog.golang.org/module-mirror-launch/proxy-protocol.png)

---

### `$GOPROXY/<module>/@v/list`

- list of known versions
- line by line

```sh
$ curl 'https://proxy.golang.org/github.com/gorilla/mux/@v/list'
v1.3.0
v1.7.0
v1.6.0
…
```

---

#### `$GOPROXY/<module>/@v/<version>.info`

- returns version details and date of creation

```sh
$ curl 'https://proxy.golang.org/github.com/gorilla/mux/@v/v1.7.0.info'
{"Version":"v1.7.0","Time":"2019-01-25T16:05:53Z"}
```

---

#### `$GOPROXY/<module>/@latest`

- not documented in `go help goproxy`
- returns details of the latest available version

```sh
$ curl 'https://proxy.golang.org/github.com/gorilla/mux/@latest'
{"Version":"v1.7.3","Time":"2019-06-30T04:17:52Z"}
```

---

#### `$GOPROXY/<module>/@v/<version>.mod`

- the module's `go.mod` file

```sh
$ curl -s 'https://proxy.golang.org/github.com/gorilla/mux/@v/v1.7.0.mod' | head
module github.com/gorilla/mux
```

---

#### `$GOPROXY/<module>/@v/<version>.zip`

- zip archive of the module at `<version>`

```sh
$ curl -s 'https://proxy.golang.org/github.com/gorilla/mux/@v/v1.7.0.zip' | bsdtar --list -zf- | head -n10
github.com/gorilla/mux@v1.7.0/.github/release-drafter.yml
github.com/gorilla/mux@v1.7.0/.github/stale.yml
github.com/gorilla/mux@v1.7.0/.travis.yml
github.com/gorilla/mux@v1.7.0/AUTHORS
github.com/gorilla/mux@v1.7.0/ISSUE_TEMPLATE.md
github.com/gorilla/mux@v1.7.0/LICENSE
github.com/gorilla/mux@v1.7.0/README.md
github.com/gorilla/mux@v1.7.0/bench_test.go
github.com/gorilla/mux@v1.7.0/context.go
github.com/gorilla/mux@v1.7.0/context_test.go
…
```

# The Zip Archive

- [is pretty special][gomodzipissue]
- root folder must be:
	
	`<import-path>@<version>/`
- it contains no metadata:
	- modification timestamps are DOS zero time (1979-11-30)
	- everything has `0644` permissions

# You Should not Zip them Yourself

- very hard to reproduce
- only achieved archives with equal byte length (compared to proxy.golang.org)
- checksums were still different (official zips used weird file metadata)

# But…

- thanks to [!34953][gomodzipissue] we now have a library [golang.org/x/mod/zip](https://godoc.org/golang.org/x/mod/zip) 🎉
- downside: the API does not work on streams, requires a folder of files
- alternative: [Athens][athens-pacmod] will be using [pacmod][pacmod]

# So…

## Should I Write one Myself?

::: incremental

- For learning, yes!
- For production, maybe?
- documentation is still unfinished and all over the place
- if a project is not using semantic versioning the API falls back to [pseudo-versions][pseudoversion]:

:::

# Pseudo-Version

- Example: `v0.0.0-20191025081138-a37363377ac6`
- uses a custom date format `20060102150405` 😐


# Pseudo Version [Format][pseudoversion]:

- `vX.0.0-yyyymmddhhmmss-abcdefabcdef`
- `vX.Y.Z-pre.0.yyyymmddhhmmss-abcdefabcdef`
- `vX.Y.(Z+1)-0.yyyymmddhhmmss-abcdefabcdef`

Not much fun to handle them.

# Further Reading

- [Katie Hockman - Go Module Proxy: Life of a Query][katiehockmangolab]
	This talk goes into a bit more detail and explains how the checksum database works (Merkel-Trees, …)
- [Go Modules in 2019][gomodules2019]
- [Go Modules Documentation][gomodulesdoc]
- [proxy.golang.org][proxygolangorg]

# Questions? { data-background-video=https://media.giphy.com/media/l0Iy8hSJalxmgTOF2/giphy.mp4 data-background-video-loop=loop data-background-opacity=0.31415 }

# Summary

A module proxy gives you:

- faster builds
- reproducible builds
- persistent dependencies

Additionally, the checksum database eliminiates MITM modification of modules.

[go15]: https://go.googlesource.com/proposal/+/master/design/25719-go15vendor.md
[go2017survey]: https://blog.golang.org/survey2017-results
[go2018survey]: https://blog.golang.org/survey2018-results
[packagemanagerlist]: https://github.com/golang/go/wiki/PackageManagementTools
[davecheney2016]: https://dave.cheney.net/2016/12/20/thinking-about-gopath
[go111]: https://blog.golang.org/go1.11
[defaultgopath]: https://github.com/golang/go/issues/17262
[modulesdocumentation]: https://github.com/golang/go/issues/34953
[vgoissue]: https://github.com/golang/go/issues/24476
[proxygolang]: https://proxy.golang.org
[sumdatabase]: https://sum.golang.org.
[gomodzipissue]: https://github.com/golang/go/issues/34953
[athens-pacmod]: https://github.com/gomods/athens/pull/1414
[pacmod]: https://github.com/plexsystems/pacmod
[katiehockmangolab]: https://www.youtube.com/watch?v=kqMxaO9d1NM
[gomodules2019]: https://blog.golang.org/modules2019
[gomodulesdoc]: https://golang.org/doc/go1.13#modules
[proxygolangorg]: https://proxy.golang.org/
[pseudoversion]: https://tip.golang.org/cmd/go/#hdr-Pseudo_versions
