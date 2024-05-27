#
# spec file for package ukit
#
# Copyright (c) 2024 Valentin LEFEBVRE
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

%define archive_name unified-kernel-image-tool

Name:           ukit
Version:        1.1.0
Release:        0
Summary:        Tool for the UKI project
License:        MIT
URL:            https://github.com/keentux/unified-kernel-image-tool.git
Source:         %{archive_name}-%{version}.tar.xz
Patch:          remove-snapshot-number-condition.patch
BuildArch:      noarch
BuildRequires:  coreutils
BuildRequires:  ShellCheck
BuildRequires:  bash-sh
Requires:       zypper
Requires:       rpm
Requires:       e2fsprogs
Requires:       bash-sh, awk, coreutils, bind-utils, binutils
Requires:       squashfs
# Require to have lsinitrd
Requires:       dracut

BuildRoot:      %{_tmppath}/%{archive_name}-%{version}-build

%description
Tool that regroup useful command dealing with the Unified Kernel Image (UKI)
project. Write in Bash script, and adapted to the packaging.

%prep
%autosetup -n %{archive_name}-%{version}

%build
sh ./build.sh

%install
export PREFIX_BIN_DIR=%{buildroot}%{_bindir}/../
sh ./install.sh

%files
%defattr(-,root,root)
%doc README.md LICENSE AUTHORS CHANGELOG.md
%{_bindir}/%{name}

%changelog