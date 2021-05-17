Name:		keyprotect-luks
Version:	1.0
Release:	1%{?dist}
Summary:	IBM HPCS Key Protect Integration with LUKS

Group:		None
License:	Apache 2.0
URL:		https://example.com
Source0:	%{name}-%{version}.tar.gz

#BuildRequires:
Requires:	python3

%description
%{name} provides integration between IBM HPCS Key Protect
and LUKS via the kernel keyring.


%prep
%setup -q


%install
make install DESTDIR=%{buildroot}


%files
%defattr(-,root,root)
%license LICENSE
%doc README.md
%attr(0755,root,root) %{_bindir}/%{name}
%attr(0644,root,root) %{_prefix}/lib/systemd/system/%{name}.service
%attr(0644,root,root) %{_sharedstatedir}/%{name}/logon
%attr(0644,root,root) %{_sharedstatedir}/%{name}/user
%attr(0644,root,root) %{_docdir}/%{name}/%{name}.ini


%changelog
* Mon May 17 2021 George Wilson <gcwilson@linux.ibm.com>
- Add key dirs and keyprotect.ini
* Thu May 06 2021 George Wilson <gcwilson@linux.ibm.com>
- Inital packaging

