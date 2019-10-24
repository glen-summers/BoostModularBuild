param ([string] $Target, [string] $Module, [string] $TempDir)
$ErrorActionPreference = "Stop"
$Temp = if ($TempDir) {$TempDir} else {"$PSScriptRoot\temp"}
$DepDir = 'ExternalDependencies'

$NugetVer = 'v4.9.4'
$NugetUrl = "https://dist.nuget.org/win-x86-commandline/$NugetVer/nuget.exe"

$SevenZipVer = '18.1.0'

$BoostVer = '1.69.0'
$ModuleUrl = "https://github.com/boostorg/`$Module`/archive/`$BoostArchive`.tar.gz"

# findstr isnt finding the '#' due to regex limitations so just add a Sanitiser filter afterwards
$Sanitiser=   "^[^:]*:[ \t]*#[ \t]*include[ \t]*<boost\/[a-zA-Z0-9\._]*[\/>]"
$BoostIncludeCapture="[ \t]*#[ \t]*include[ \t]*<boost\/([a-zA-Z0-9\._]*)[\/|>].*"

function Init
{
	$global:Downloads = "$temp\downloads"
	$global:Nuget = "$Downloads\nuget.exe"
	$global:SevenZip = "$Downloads\7-Zip.CommandLine.$SevenZipVer\tools\x64\7za.exe"
	$global:BoostArchive = "boost-$BoostVer"
	$global:BoostVerUnd = 'boost_' + $BoostVer.Replace('.', '_')
	$global:TempModules = "$temp\modules"
	$global:Above = Get-DirectoryAbove $PSScriptRoot $DepDir $Temp

	md $Downloads -Force | Out-Null
	Download-File $NugetUrl $Nuget
	Download-Nuget $SevenZip $SevenZipVer
}

function Main
{
	cls

	Switch ($Target)
	{
		'build'
		{
			if (!$Module)
			{
				"Syntax: build <RootModule> [<TempDir>]"
				return
			}

			Init
			$Target = Join-Path $Above ($BoostVerUnd + '_' + $Module)
			$TouchFile = Join-Path $Target 'successfully_installed'
			if (! (Test-Path $TouchFile))
			{
				[string[]] $Deps = Get-Deps $Module | ? { $_ }
				$Deps += $Module
				Write-Host "building $Target"

				md $Target -Force | Out-Null
				foreach ($mod in $Deps)
				{
					$ModDir = Get-Module $mod
					Copy-Item $ModDir\include\boost $Target -Force -Recurse # try move but avoid conflicts?
				}
				echo $null >> $TouchFile
				Delete-Tree $TempModules
			}

			Write-Host $Target
			Get-Item $Target | Get-ChildItem -r | Measure-Object -Sum Length | `
				Select-Object @{Name=”Path”; Expression={$directory.FullName}}, @{Name=”Files”; Expression={$_.Count}}, @{Name=”Size”; Expression={$_.Sum}}
		}

		'gen' # gets all boost modules and scans to generate rules for their locations
		{
			Init

			$Libs = Get-Libs
			$OutName = "$Temp/gen.txt"

			if (Test-Path $OutName)
			{
				Remove-Item $OutName
			}

			foreach ($Module in $Libs)
			{
				$ModDir = Get-Module $Module

				[string[]] $files = (gci $ModDir\include\boost\*.* -Include *.h,*.hpp).BaseName
				$Joined = $files -join '|'

				if ($files.length -ne 0)
				{
					if ($files.length -eq 1 )
					{
						if ($Joined -ne $Module)
						{
							Add-Content $OutName "if (`$_ -eq `"$Joined`") { `"$Module`" }"
							Add-Content $OutName "else" -NoNewline
						}
					}
					else
					{
						Add-Content $OutName "if (`$_ -match `"^($Joined)$`") { `"$Module`" }"
						Add-Content $OutName "else" -NoNewline 
					}
				}
			}
			Add-Content $OutName " {`$_}"

			# keep this in git and include directly?
			type $OutName
		}

		'deps' # get all nested dependencies of specified module
		{
			if (!$Module)
			{
				'Syntax: deps <RootModule>'
				return
			}

			Write-Host "deps $Module"

			Init
			[string[]] $Deps = Get-Deps $Module | ? { $_ }
			Write-Host "$Module dependencies : " $Deps.length
			Write-Host $Deps
		}

		'all'
		{
			# test target to verify all modules resolve deps ok
			Init
			$all = Get-Libs
			Get-Deps $all
			# todo build visual dependency tree?
		}

		'clean'
		{
			Delete-Tree $Temp
		}

		'nuke'
		{
			if (!$Module)
			{
				'Syntax: nuke <RootModule>'
				return
			}

			Init
			$Target = Join-Path $Above ($BoostVerUnd + '_' + $Module)
			Delete-Tree $Target
		}

		default
		{
			'Syntax: build <RootModule>|deps <RootModule>|clean|nuke|gen
    build <mod>    Generates an include directory with all <mod>''s dependencies
    deps <mod>     Displays all dependencies of <mod>
    clean          remove temp files
    nuke <mod>     remove the built target
    gen            generate module file lookup code'
		}
	}
}

function Get-BoostModuleName
{ 
	[CmdletBinding()]
	Param([Parameter(ValueFromPipeline)] $item)

	# todo verify replacement list
	# check concept?
	process
	{
		$item                                                                    `
		-replace "^[^:]*:",""                                                    `
		-replace "\/\/.*",""                                                     `
		-replace "\/\*.*\*\/",""                                                 `
		-replace "^\s*#\s*pragma.*$",""                                          `
		-replace "<boost\/numeric\/conversion\/","<boost/numeric_conversion/"    `
		-replace "<boost\/numeric\/ublas\/","<boost/ublas/"                      `
		-replace "<boost\/archive\/","<boost/serialization/"                     `
		-replace "<boost\/functional\/hash.hpp","<boost/container_hash/hash.hpp" `
		-replace "<boost\/concept\/","<boost/concept_check/"                     `
		-replace "<boost\/detail\/([^\/]+)\/","<boost/`$1/"                      `
		-replace $BoostIncludeCapture, "`$1"                                     `
		-replace "\/|\.hp?p?| ",""
	}
}

function Get-ModuleFromRootFile
{
	[CmdletBinding()]
	Param([Parameter(ValueFromPipeline)] $item)

	process
	{
		# match files in root include/boost directory back to originating module
		# generated from the gen target
		    if ($_ -match "^(assert|current_function)$") { "assert" }
		elseif ($_ -match "^(atomic|memory_order)$") { "atomic" }
		elseif ($_ -match "^(bind|is_placeholder|mem_fn)$") { "bind" }
		elseif ($_ -match "^(circular_buffer|circular_buffer_fwd)$") { "circular_buffer" }
		elseif ($_ -match "^(concept_archetype|concept_check)$") { "concept_check" }
		elseif ($_ -match "^(config|cstdint|cxx11_char_types|limits|version)$") { "config" }
		elseif ($_ -match "^(contract|contract_macro)$") { "contract" }
		elseif ($_ -match "^(implicit_cast|polymorphic_cast|polymorphic_pointer_cast)$") { "conversion" }
		elseif ($_ -match "^(convert|make_default)$") { "convert" }
		elseif ($_ -match "^(checked_delete|get_pointer|iterator|noncopyable|non_type|ref|swap|type|visit_each)$") { "core" }
		elseif ($_ -match "^(blank|blank_fwd|cstdlib)$") { "detail" }
		elseif ($_ -match "^(dynamic_bitset|dynamic_bitset_fwd)$") { "dynamic_bitset" }
		elseif ($_ -eq "exception_ptr") { "exception" }
		elseif ($_ -match "^(foreach|foreach_fwd)$") { "foreach" }
		elseif ($_ -match "^(function|function_equal)$") { "function" }
		elseif ($_ -match "^(integer|integer_fwd|integer_traits)$") { "integer" }
		elseif ($_ -eq "io_fwd") { "io" }
		elseif ($_ -match "^(function_output_iterator|generator_iterator|indirect_reference|iterator_adaptors|next_prior|pointee|shared_container_iterator)$") { "iterator" }
		elseif ($_ -match "^(cstdfloat|math_fwd)$") { "math" }
		elseif ($_ -match "^(multi_index_container|multi_index_container_fwd)$") { "multi_index" }
		elseif ($_ -match "^(none|none_t|optional)$") { "optional" }
		elseif ($_ -match "^(nondet_random|random)$") { "random" }
		elseif ($_ -match "^(cregex|regex|regex|regex_fwd)$") { "regex" }
		elseif ($_ -match "^(enable_shared_from_this|intrusive_ptr|make_shared|make_unique|pointer_cast|pointer_to_other|scoped_array|scoped_ptr|shared_array|shared_ptr|smart_ptr|weak_ptr)$") { "smart_ptr" }
		elseif ($_ -eq "cerrno") { "system" }
		elseif ($_ -match "^(progress|timer)$") { "timer" }
		elseif ($_ -match "^(tokenizer|token_functions|token_iterator)$") { "tokenizer" }
		elseif ($_ -match "^(aligned_storage|type_traits)$") { "type_traits" }
		elseif ($_ -match "^(unordered_map|unordered_set)$") { "unordered" }
		elseif ($_ -match "^(call_traits|compressed_pair|operators|operators_v1|utility)$") { "utility" }
		elseif ($_ -eq "cast") { "numeric_conversion" }
		else {$_}
		# generated from the gen target 
	}
}

function Get-Module
{
	[CmdletBinding()]
	param ([string] $Module)
	$ModArchive="$Module-$BoostArchive"
	$FileName="$Downloads\$ModArchive.tar.gz"
	$Url = $ExecutionContext.InvokeCommand.ExpandString($ModuleUrl)
	Download-File $Url $FileName

	$Target = "$TempModules\$Module"
	if (-not (Test-Path $Target)) {
		ExtractTarGz $FileName $Target
	}
	"$Target\$ModArchive"
}

function Calc-Dependencies
{
	[CmdletBinding()]
	param ([string] $Module)

	Write-Host "scanning for '$Module' dependencies... " -NoNewline
	$ModDir = Get-Module $Module

	$KnownLibs = Get-Libs
	# pending caused by test code : include\boost\pending\iterator_tests.hpp
	# numeric from files missing from e.g. ublas\functional.hpp:#include <boost/numeric/bindings/traits/std_vector.hpp>
	$Ignore = $Module,"pending","numeric"

	# just includes for now
	pushd "$ModDir\include\boost"

	[string[]] $files='*.h','*.hpp','*.ipp'

	[string[]] $Groups = $(findstr /si /C:"include <boost/" $files) | ? { $_ -match $Sanitiser } |
		Get-BoostModuleName | ? { $_ -ne ""} | sort | unique | Get-ModuleFromRootFile | sort | unique |
			? { $Ignore -notcontains $_ } | % {
				if ($KnownLibs -notcontains $_)
				{
					# rerun findstr to show the includes causing the unknown lib
					$(findstr /si /C:"include <boost/$_" $files) | % { Write-Host $_ }
					throw "Unknown library dependency : '$_'"
				}
			$_
		}
	popd
	write-host $(If ($Groups.length -eq 0) {"(none)"} Else {"$Groups"})
	$Groups | ? { $_ } # still gets empty values returned
}

function Get-Libs
{
	$ModDir = Get-Module 'boost'

	# numeric: -> numeric_conversion interval odeint ublas
	$Ignore='numeric'
	[string[]] $Add='numeric_conversion', 'interval', 'odeint', 'ublas'

	$BoostLibs = gci "$ModDir\libs" -Directory -Name | ? { $Ignore -notcontains $_ }
	$BoostLibs + $Add
}

function Get-Deps
{
	param ([string[]] $Modules)

	[string[]] $Mods = $Modules | sort | unique
	[string[]] $Deps
	[string[]] $Ignore = $Mods

	do
	{
		$Mods = $Mods.Where({ $_ -ne ""}) | % { Calc-Dependencies $_ -ErrorAction Stop } | ? { $Ignore -notcontains $_ } # at front?
		$Deps = ($Deps + $Mods) | sort | unique
		$Ignore = ($Ignore + $Mods) | sort | unique
	} while ($Mods.Length -ne 0)

	#$Deps.Where({ $_.length -ne 0})
	$Deps | ? {$_}
}

###########################################################################

function Get-DirectoryAbove
{
	param ([string] $Start, [string] $Signature, [string] $Fallback)

	for ($dir = $Start; $dir; $dir = Split-Path -Path $dir -Parent)
	{
		$combined = Join-Path $dir $Signature
		if (Test-Path $combined)
		{
			$combined
			return
		}
	}
	$Fallback
}

function Download-File
{
	[CmdletBinding()]
	param ([string]$Url, [string]$Target)

	if ( -Not (Test-Path $Target ))
	{
		Write-Host "downloading $Url -> $Target"
		(New-Object System.Net.WebClient).DownloadFile($Url, $Target)
		if ( -Not (Test-Path $Target ))
		{
			throw 'Download failed'
		}
	}
}

function Download-Nuget
{
	param ([string]$Name, [string]$Version)
	if ( -Not (Test-Path $Name))
	{
		Write-Host "downloading $Name"
		& $Nuget install 7-Zip.CommandLine -version "$Version" -OutputDirectory "$Downloads" -PackageSaveMode nuspec
	}
}

function ExtractTarGz
{
	param ([string]$Archive, [string]$OutDir)
	(& cmd /c $SevenZip x $Archive -so `| $SevenZip x -aoa -si -ttar -o"$OutDir") 2>&1 | Out-Null
}

function Delete-Tree
{
	param ([string]$Dir)

	if (-not (Test-Path $Dir)) {
		return
	}

	Write-Host "deleting $Dir..."
	$tries = 10
	while ((Test-Path $Dir) -and ($tries-ge 0)) {
		Try {
			rm -r -fo $Dir
			return
		}
		Catch {
		}
		Start-Sleep -seconds 1
		--$tries
	}
	Write-Host "failed to delete"
}

###########################################################################

Main