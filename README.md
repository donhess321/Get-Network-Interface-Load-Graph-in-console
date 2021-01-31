# Get-Network-Interface-Load-Graph-in-console
Show a console based graph of the load for each network interface.  This works over SSHor PS remoting. I use it for a quick check on server core networking. Color output is optional.  The graph scale changes to follow the traffic so it will start at 1M and scales 10x each increment. It accesses the performance counters via WMI on the local machine.  

![Output Sample](https://github.com/donhess321/Get-Network-Interface-Load-Graph-in-console/blob/main/output_sample.png)

This is a reposting from my Microsoft Technet Gallery.
