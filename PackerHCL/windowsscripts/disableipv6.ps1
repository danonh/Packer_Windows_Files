$nic = get-netadapter
Disable-NetAdapterBinding -Name $nic.name -ComponentID ms_tcpip6