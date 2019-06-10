### Command line tools to build a local boost subset installation
Windows and Linux scripts to downloads tar.gz snapshots of boost module source code from github and parse the c++ code to determine dependent modules. Then the dependency graph is used to build a boost subset directory.
```
Syntax: build <RootModule>|deps <RootModule>|clean|nuke|gen
    build <mod>    Generates an include directory with all <mod>'s dependencies
    deps <mod>     Displays all dependencies of <mod>
    clean          remove temp files
    nuke <mod>     remove the built target
    gen            generate module file lookup code
```
#### Motivation
I was interested in using the boost test library for unit testing, but my original boost solution includes the entire boost source code and also required https openssl support for boost beast, the download and compilation footprint is substantial. A more lightweight option would be preferable. I also looked at vcpkg library manager which does have the facility to build a modular boost installation but the dependency code appeared to have omissions so I had a go at writing a lightweight c++ #include scanner script.

#### build \<module\>
Scans dependencies of module and builds a composite boost directory **boost_\<ver\>_\<module\>**  in a parent **ExternalDependencies** directory 
```
> go build test
scanning for 'test' dependencies...
building C:\Users\Zardoz\source\ExternalDependencies\boost_1_69_0_test
deleting C:\Users\Zardoz\source\repos\github\BoostModularBuild\temp\modules...

C:\Users\Zardoz\source\ExternalDependencies\boost_1_69_0_test
Path Files     Size
---- -----     ----
      4113 37791006
```
```
$ ./go.sh build test
build test
Building /mnt/c/Users/Zardoz/source/ExternalDependencies/boost_1_69_0_TEST with 40 mods : algorithm array assert bind concept_check config container container_hash conversion core detail exception function function_types fusion integer intrusive io iterator move mpl numeric_conversion optional predef preprocessor range regex smart_ptr static_assert system test throw_exception timer tuple type_index typeof type_traits unordered utility winapi
deleting /mnt/c/Users/Zardoz/source/repos/github/BoostModularBuild/temp/modules...
44M     /mnt/c/Users/Zardoz/source/ExternalDependencies/boost_1_69_0_TEST
```
#### deps \<module\>
Scans and lists dependencies of module
```
> go deps test
scanning for 'test' dependencies...
test dependencies :  40
algorithm array assert bind concept_check config container container_hash conversion core detail exception function function_types functional fusion integer intrusive io iterator move mpl numeric_conversion optional predef preprocessor range regex smart_ptr static_assert system throw_exception timer tuple type_index type_traits typeof unordered utility winapi
```
#### nuke \<mod\>
removes the target built by a **build \<module\>**
```
> go nuke test
deleting C:\Users\Zardoz\source\ExternalDependencies\boost_1_69_0_test...
>
```
