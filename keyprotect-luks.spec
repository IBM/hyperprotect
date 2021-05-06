Name:		keyprotect-luks
Version:	1.0
Release:	1%{?dist}
Summary:	IBM HPCS Key Protect Integration with LUKS

Group:		None
License:	Apache 2.0
URL:		https://example.com
Source0:	keyprotect-luks.tar.gz

BuildRequires:
Requires:	python3

%description
keyprotect-luks provides integration between IBM HPCS Key Protect
and LUKS via the kernel keyring.


%prep
%setup -q


#%build
#%configure
#make %{?_smp_mflags}


%install
#%make_install
scons install


%files
%defattr(-,root,root)
%license LICENSE
%doc README.md
%attr(0755,root,root) %{_bindir}/keyprotect-luks
%attr(0644,root,root) %{_exec_prefix}/keyprotect-luks.service


%changelog
* Thu May 06 2021 George Wilson <gcwilson@linux.ibm.com>
- inital packaging

