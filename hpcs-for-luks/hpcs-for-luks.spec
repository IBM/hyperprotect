Name:		hpcs-for-luks
%include version.inc
Release:	1%{?dist}
Summary:	IBM Key Protect Integration with LUKS
BuildArch:	noarch

Group:		None
License:	Apache 2.0
URL:		https://example.com
Source0:	%{name}-%{version}.tar.gz

#BuildRequires:
Requires:	python3

%description
%{name} provides integration between IBM Key Protect
and LUKS via the kernel keyring.

%global UTILITY_NAME hpcs-for-luks
%global BUILD_AND_PACKAGE_DRACUT 1

%prep
%setup -q


%install
%if "%{BUILD_AND_PACKAGE_DRACUT}" == "1"
make install install-dracut DESTDIR=%{buildroot}
%else
make install DESTDIR=%{buildroot}
%endif


%files
%defattr(-,root,root)
%license LICENSE
%doc README.md
%attr(0755,root,root) %{_bindir}/%{UTILITY_NAME}
%attr(0644,root,root) %config(noreplace) %{_sysconfdir}/%{UTILITY_NAME}.ini
%attr(0644,root,root) %{_prefix}/lib/systemd/system/%{UTILITY_NAME}.service
%attr(0644,root,root) %{_prefix}/lib/systemd/system/%{UTILITY_NAME}-wipe.service
%attr(0644,root,root) %{_sharedstatedir}/%{UTILITY_NAME}/logon
%attr(0644,root,root) %{_sharedstatedir}/%{UTILITY_NAME}/user
%attr(0644,root,root) %{_mandir}/man1/%{UTILITY_NAME}.1.gz
%if "%{BUILD_AND_PACKAGE_DRACUT}" == "1"
%attr(0755,root,root) %{_prefix}/lib/dracut/modules.d/95%{UTILITY_NAME}/%{UTILITY_NAME}-dracut.sh
%attr(0644,root,root) %{_prefix}/lib/dracut/modules.d/95%{UTILITY_NAME}/%{UTILITY_NAME}-dracut.service
%attr(0755,root,root) %{_prefix}/lib/dracut/modules.d/95%{UTILITY_NAME}/module-setup.sh
%attr(0644,root,root) %{_prefix}/lib/tmpfiles.d/cryptsetup-tmpfiles.conf
%attr(0644,root,root) %{_sysconfdir}/dracut.conf.d/%{UTILITY_NAME}.conf
%attr(0755,root,root) %{_prefix}/lib/dracut/modules.d/83tss/module-setup.sh
%attr(0755,root,root) %{_prefix}/lib/dracut/modules.d/83tss/start-tcsd.sh
%attr(0755,root,root) %{_prefix}/lib/dracut/modules.d/83tss/stop-tcsd.sh
%attr(0755,root,root) %{_prefix}/lib/dracut/modules.d/83tss/run-tss-cmds.sh
%attr(0644,root,root) %{_sysconfdir}/dracut.conf.d/tss.conf
%attr(0644,root,root) %{_docdir}/%{UTILITY_NAME}/examples/%{UTILITY_NAME}-rootfs-config.sh
%endif

%changelog
* Wed Apr 10 2024 George Wilson <gcwilson@linux.ibm.com>
- Package rootfs config script
* Wed Nov  8 2023 George Wilson <gcwilson@linux.ibm.com>
- Package dracut files
* Sun Oct 22 2023 Sam Matzek <smatzek@us.ibm.com>
- Complete dracut module
* Fri Apr 22 2022 George Wilson <gcwilson@linux.ibm.com>
- Change package name to hpcs-for-luks
* Wed Feb 16 2022 George Wilson <gcwilson@linux.ibm.com>
- Remove HPCS from name, package ini file in /etc
* Tue Feb 15 2022 George Wilson <gcwilson@linux.ibm.com>
- Package manpage
* Thu Jan 13 2022 George Wilson <gcwilson@linux.ibm.com>
- Add BUILD_AND_PACKAGE_DRACUT conditional
* Fri Jun 18 2021 George Wilson <gcwilson@linux.ibm.com>
- Add tss dracut module
* Wed Jun 16 2021 George Wilson <gcwilson@linux.ibm.com>
- Add dracutl module skeleton
* Mon May 17 2021 George Wilson <gcwilson@linux.ibm.com>
- Add key dirs and keyprotect.ini
* Thu May 06 2021 George Wilson <gcwilson@linux.ibm.com>
- Inital packaging

