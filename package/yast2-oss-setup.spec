#
# spec file for package yast2-oss-setup
#
# Copyright (c) 2016 Peter Varkoly, Nuernberg, Germany.
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via http://bugs.opensuse.org/
#

Name:           yast2-oss-setup
Version:	4.0
Release:	0
License:	Commercial
Summary:	Setup for OSS
Url:		www.openschoolserver.net
Group:		System/YaS
Source:		%{name}-%{version}.tar.bz2
BuildRequires:	yast2 yast2-ruby-bindings yast2-devtools
BuildRequires:  rubygem(yast-rake) rubygem(rspec)
Requires:       yast2
Requires:	oss-base
BuildRoot:      %{_tmppath}/%{name}-%{version}-build

%description
Setup for OSS


%prep
%setup -q

%build

%install
rake install DESTDIR=%{buildroot}

%post

%postun

%files
%defattr(-,root,root)
%doc README.md
/usr/share/YaST2/clients/
/usr/share/YaST2/lib/oss-setup/
/usr/share/YaST2/scrconf/etc_schoolserver.scr
