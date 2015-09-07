#!/usr/bin/perl  -w 
use strict;
package drac_api;


my $output_file="/var/log/drac_api.log";
open(OUTFILE,">>$output_file") or die "Cannot open $output_file \n";
my @timenow;

sub new {
	my $self = {};
        bless($self);
        return $self;
}

sub DESTROY {
	my $self = shift;
	close(OUTFILE);
}

## Get physical Disks info
sub get_pdisks{

	my ($self,$drac_ip,$username,$password)=@_;
	my @cmd=`racadm -r $drac_ip -u $username -p '$password' raid get pdisks -o -p state,size | grep "Disk"`;
	return @cmd;

}

## Get physical disks size
sub get_pdisks_size{
	my ($self,$drac_ip,$username,$password)=@_;
        my @cmd=`racadm -r $drac_ip -u $username -p '$password' raid get pdisks -o -p state,size | grep "Size" | awk 'BEGIN { FS = "= " } ; { print \$2 }'`;
        return @cmd;

}

## Get HW inventory
sub get_hwinventory{
	my ($self,$drac_ip,$username,$password)=@_;
	my $cmd=`racadm -r $drac_ip -u $username -p '$password' hwinventory`;
	return $cmd;

}

## Get Network Interface Info
sub get_nics{
	my ($self,$drac_ip,$username,$password)=@_;
	my @cmd=`racadm -r $drac_ip -u $username -p '$password' get nic.nicconfig | grep -i nic | awk 'BEGIN { FS = "[" } ; { print \$1 }'`;
	return @cmd;
}

## Get NICs fully domain name
sub get_nic_fddn{
	my ($self,$drac_ip,$username,$password)=@_;
	my @cmd=`racadm -r $drac_ip -u $username -p '$password' get nic.nicconfig | grep -i nic | awk 'BEGIN { FS = "[" } ; { print \$2 }' | awk 'BEGIN { FS = "#" } ; { print \$1 }' | awk 'BEGIN { FS = "=" } ; { print \$2 }'`;
	return @cmd;
}

## Get virtual Disks info
sub get_vdisks{

	my ($self,$drac_ip,$username,$password)=@_;
	my @cmd=`racadm -r $drac_ip -u $username -p '$password' raid get vdisks -o -p state,size | grep "Disk"`;	
	return @cmd;
}

## Set Next Boot to PXE
sub set_nextboot_pxe{

	my ($self,$drac_ip,$username,$password)=@_;
	my @cmd=`racadm -r $drac_ip -u $username -p '$password' config -g cfgServerInfo -o cfgServerFirstBootDevice PXE`;
	return 0;
}

## Enable Life Cycle Controller
sub enable_lifecycle{

	my ($self,$drac_ip,$username,$password)=@_;
        my @cmd=`racadm -r $drac_ip -u $username -p '$password' set LifecycleController.LCAttributes.LifecycleControllerState 1`;
        return 0;

}

## Get Key for Bios
sub get_boot_key{
	my ($self,$drac_ip,$username,$password)=@_;
	my $cmd=`racadm -r $drac_ip -u $username -p '$password' get bios.biosbootSettings.bootseq | grep -i key`;
	return $cmd;
}

## Get Key for Memory
sub get_mem_key{
	my ($self,$drac_ip,$username,$password)=@_;
	my $cmd=`racadm -r $drac_ip -u $username -p '$password' get BIOS.MemSettings  | grep -i key`;
        return $cmd;
}

## Get Boot Preferences
sub get_boot_pref{
	my ($self,$drac_ip,$username,$password)=@_;
        my $cmd=`racadm -r $drac_ip -u $username -p '$password' get bios.biosbootSettings.bootseq | grep -i BootSeq`;
        return $cmd;
}

## Get Memory Mode
sub get_memop_mode{
	my ($self,$drac_ip,$username,$password)=@_;
	my $cmd=`racadm -r $drac_ip -u $username -p '$password' get BIOS.MemSettings  | grep -i MemOpMode`;
        return $cmd;
}

## Get Logical Processor Mode
sub get_logicalproc_mode{
	my ($self,$drac_ip,$username,$password)=@_;
        my $cmd=`racadm -r $drac_ip -u $username -p '$password' get BIOS.ProcSettings  | grep -i LogicalProc`;
        return $cmd;
}

## Setting Boot Mode
sub set_boot_mode{
        my ($self,$drac_ip,$username,$password,$bootmode)=@_;
	my $current_boot_setting = `racadm -r $drac_ip -u $username -p '$password'  get bios.biosbootsettings.BootMode  | grep -i BootMode | awk -F '=' '{print \$2}' | awk '{print \$1}'`;
	chomp($current_boot_setting);
	if ($current_boot_setting =~ $bootmode) {
		@timenow=$self->gettime();
		print OUTFILE "@timenow - $drac_ip - $bootmode - BootMode is  already $bootmode\n";
		return 0;
	}	
        my $key_details=`racadm -r $drac_ip -u $username -p '$password'  get bios.biosbootsettings.BootMode  | grep -i key`;
        my @split1=split("Key=",$key_details);

        my $key=$split1[1];
        $key=~ s/^\s+|\s+$//g;
        chomp($key);
        my @split3=split("#",$key);
        $key=$split3[0];
        chomp($key);
        @timenow=$self->gettime();


        my $output=`racadm -r $drac_ip -u $username -p '$password' set bios.biosbootsettings.BootMode $bootmode`;
        my $exit_status=`echo $?`;
        print OUTFILE "@timenow - $drac_ip - $key - SETBIOSMode - $output\n";
        print OUTFILE "@timenow - $drac_ip - $key - SETBIOSMode - Exit Status: $exit_status\n";
        chop($exit_status);
        if($exit_status ne 0)
        {
                return $exit_status;
        }
        my $return=$self->schedule_job($drac_ip,$username,$password,$key,$key);
        if($return ne  0)
        {
                return $return;
        }

        return 0;
}

## Setting Memory Operation Mode
sub set_memop_mode{

	my ($self,$drac_ip,$username,$password)=@_;
        my $key_details=$self->get_mem_key($drac_ip,$username,$password);
        my @split1=split("Key=",$key_details);

        my $key=$split1[1];
        $key=~ s/^\s+|\s+$//g;
        chomp($key);
        my @split3=split("#",$key);
        $key=$split3[0];
        chomp($key);
	
	my $mem_mode=$self->get_memop_mode($drac_ip,$username,$password);
	$mem_mode=~ s/^\s+|\s+$//g;

	@timenow=$self->gettime();
	 if(index($mem_mode, "MirrorMode") != -1)
        {
        	if(index($mem_mode,"Pending") != -1)
                {
			 print OUTFILE "@timenow - $drac_ip - $key - MirrorMode in pending state\n";
                }
                else
                {
			print OUTFILE "@timenow - $drac_ip - $key - MirrorMode already set\n";
                        return 0;
                }
        }
        @timenow=$self->gettime();

        my $output=`racadm -r $drac_ip -u $username -p '$password' set BIOS.MemSettings.MemOpMode MirrorMode`;
        my $exit_status=`echo $?`;
        print OUTFILE "@timenow - $drac_ip - $key - SETMemMode - $output\n";
        print OUTFILE "@timenow - $drac_ip - $key - SETMemMode - Exit Status : $exit_status\n";
        chop($exit_status);
        if($exit_status ne 0)
        {
                return $exit_status;
        }
        my $return=$self->schedule_job($drac_ip,$username,$password,$key,$key);
        if($return ne  0)
        {
                return $return;
        }

        return 0;
	
}

## Disable Hyperthreading
sub disable_ht{
	my ($self,$drac_ip,$username,$password)=@_;
        my $key_details=$self->get_mem_key($drac_ip,$username,$password);
        my @split1=split("Key=",$key_details);
        my $key=$split1[1];
        $key=~ s/^\s+|\s+$//g;
        chomp($key);
        my @split3=split("#",$key);
        $key=$split3[0];
        chomp($key);
        my $logical_mode=$self->get_logicalproc_mode($drac_ip,$username,$password);
        $logical_mode=~ s/^\s+|\s+$//g;
        @timenow=$self->gettime();
         if(index($logical_mode, "Disabled") != -1)
        {
		if(index($logical_mode,"Pending") != -1)
                {
			print OUTFILE "@timenow - $drac_ip - $key - LogicalMode in pending state\n";
                }
                else
		{
			print OUTFILE "@timenow - $drac_ip - $key - LogicalMode already disabled\n";
                        return 0;
                }
        }
        @timenow=$self->gettime();
        my $output=`racadm -r $drac_ip -u $username -p '$password' set BIOS.ProcSettings.LogicalProc Disabled`;
        my $exit_status=`echo $?`;
        print OUTFILE "@timenow - $drac_ip - $key - LogicalProcMode - $output\n";
        print OUTFILE "@timenow - $drac_ip - $key - LogicalProcMemMode - Exit Status : $exit_status\n";
        chop($exit_status);
        if($exit_status ne 0)
        {
                return $exit_status;
        }
        my $return=$self->schedule_job($drac_ip,$username,$password,$key,$key);
        if($return ne  0)
        {
                return $return;
        }

        return 0;
}

## Enable Hyperthreading
sub enable_ht{
        my ($self,$drac_ip,$username,$password)=@_;
        my $key_details=$self->get_mem_key($drac_ip,$username,$password);
        my @split1=split("Key=",$key_details);
        my $key=$split1[1];
        $key=~ s/^\s+|\s+$//g;
        chomp($key);
        my @split3=split("#",$key);
        $key=$split3[0];
        chomp($key);
        my $logical_mode=$self->get_logicalproc_mode($drac_ip,$username,$password);
        $logical_mode=~ s/^\s+|\s+$//g;
        @timenow=$self->gettime();
         if(index($logical_mode, "Enabled") != -1)
        {
                if(index($logical_mode,"Pending") != -1)
                {
                        print OUTFILE "@timenow - $drac_ip - $key - LogicalMode in pending state\n";
                }
                else
                {
                        print OUTFILE "@timenow - $drac_ip - $key - LogicalMode already enabled\n";
                        return 0;
                }
        }
        @timenow=$self->gettime();
        my $output=`racadm -r $drac_ip -u $username -p '$password' set BIOS.ProcSettings.LogicalProc Enabled`;
        my $exit_status=`echo $?`;
        print OUTFILE "@timenow - $drac_ip - $key - LogicalProcMode - $output\n";
        print OUTFILE "@timenow - $drac_ip - $key - LogicalProcMemMode - Exit Status : $exit_status\n";
        chop($exit_status);
        if($exit_status ne 0)
        {
                return $exit_status;
        }
        my $return=$self->schedule_job($drac_ip,$username,$password,$key,$key);
        if($return ne  0)
        {
                return $return;
        }

        return 0;
}


## Set Next Boot to PXE
sub set_boot_pxe{
	
	my ($self,$drac_ip,$username,$password)=@_;
        my $key_details=$self->get_boot_key($drac_ip,$username,$password);
	my @split1=split("Key=",$key_details);
	
	my $key=$split1[1];
	$key=~ s/^\s+|\s+$//g;
	chomp($key);
	my @split3=split("#",$key);
	$key=$split3[0];
	chomp($key);

	my $boot_details=$self->get_boot_pref($drac_ip,$username,$password);
	@split1=split("BootSeq=",$boot_details);
	my $pref=$split1[1];
	$pref=~ s/^\s+|\s+$//g;
	chomp($pref);

	my @prefs=split(",",$pref);
	my $nic=3;
	my $first_pref="NIC.Integrated.1-$nic-1";
	my $pref_order="$first_pref";
	foreach my $p(@prefs)
	{
		if($p eq $first_pref)
		{
			next;
		}
		$pref_order="$pref_order,"."$p";
	}
	my $vdtype=$key;
	@timenow=gettime();
	my $output=`racadm -r $drac_ip -u $username -p '$password' set BIOS.BiosBootSettings.bootseq $pref_order`;
        my $exit_status=`echo $?`;
        print OUTFILE "@timenow - $drac_ip - $vdtype - BIOSBOOT - $output\n";
        print OUTFILE "@timenow - $drac_ip - $vdtype - BIOSBOOT - Exit Status : $exit_status\n";
        chop($exit_status);
        if($exit_status ne 0)
        {
                return $exit_status;
        }
        my $return=$self->schedule_job($drac_ip,$username,$password,$vdtype,$vdtype);
        if($return ne  0)
        {
                return $return;
        }
	return 0;


}

## Set primary BootDev to HDD
sub set_boot_hdd{


	my ($self,$drac_ip,$username,$password)=@_;
        my $key_details=$self->get_boot_key($drac_ip,$username,$password);
        my @split1=split("Key=",$key_details);
        
        my $key=$split1[1];
        $key=~ s/^\s+|\s+$//g;
        chomp($key);
	my @split3=split("#",$key);
        $key=$split3[0];
        chomp($key);


        my $boot_details=$self->get_boot_pref($drac_ip,$username,$password);
        @split1=split("BootSeq=",$boot_details);
        my $pref=$split1[1];
        $pref=~ s/^\s+|\s+$//g;
        chomp($pref);

        my @prefs=split(",",$pref);
        my $first_pref="HardDisk.List.1-1";
        my $pref_order="$first_pref";
        foreach my $p(@prefs)
        {
                if($p eq $first_pref)
                {
                        next;
                }
                $pref_order="$pref_order,"."$p";
        }
        my $vdtype=$key;
        @timenow=gettime();
        my $output=`racadm -r $drac_ip -u $username -p '$password' set BIOS.BiosBootSettings.bootseq $pref_order`;
        my $exit_status=`echo $?`;
        print OUTFILE "@timenow - $drac_ip - $vdtype - BIOSBOOT - $output\n";
        print OUTFILE "@timenow - $drac_ip - $vdtype - BIOSBOOT - Exit Status : $exit_status\n";
        chop($exit_status);
        if($exit_status ne 0)
        {
                return $exit_status;
        }
        my $return=$self->schedule_job($drac_ip,$username,$password,$vdtype,$vdtype);
        if($return ne  0)
        {
                return $return;
        }

	return 0;

}

## Reboot
sub reboot{
	my ($self,$drac_ip,$username,$password)=@_;
	my @cmd=`racadm -r $drac_ip -u $username -p '$password' serveraction hardreset`;
	return 0;
}

## Delete all Virtual Disks
sub delete_all_vds{

	my ($self,$drac_ip,$username,$password)=@_;
	@timenow=$self->gettime();
	print OUTFILE "@timenow - $drac_ip - Going for Reboot \n";
	`racadm -r $drac_ip -u $username -p '$password' serveraction hardreset`;
   	print OUTFILE "@timenow - $drac_ip - Sleeping for 120s for the box to boot up \n"; 
	sleep(120);
	my @vds=$self->get_vdisks($drac_ip,$username,$password);
	my $temp_vds="@vds";
	my @vdisks=split("\n",$temp_vds);
		
	foreach my $vd(@vdisks)
	{

		$vd =~ s/^\s+|\s+$//g;
		@timenow=$self->gettime();
		my $output=`racadm -r $drac_ip -u $username -p '$password' raid deletevd:$vd`;
		my $exit_status=`echo $?`;
		print OUTFILE "@timenow - $drac_ip - $vd - DELETEVD - $output\n";
		print OUTFILE "@timenow - $drac_ip - $vd - DELETEVD - Exit Status : $exit_status\n";
		chop($exit_status);

		if($exit_status ne 0)
		{
			return $exit_status;
		}
		my @vdtypes=split(":",$vd);
		my $vdtype=$vdtypes[1];
		$vdtype=~ s/^\s+|\s+$//g;
		my $return=$self->schedule_job($drac_ip,$username,$password,$vd,$vdtype);	
		if($return ne  0)
                {
                        return $return;
                }		

	}
	return 0;	
}


## Reset raid 
sub reset_raid{

	my ($self,$drac_ip,$username,$password)=@_;
	my @vds=$self->get_vdisks($drac_ip,$username,$password);
        my $temp_vds="@vds";
        my @vdisks=split("\n",$temp_vds);

	my @vdtypes=split(":",$vdisks[0]);
	my $vdtype=$vdtypes[1];
        $vdtype=~ s/^\s+|\s+$//g;
	@timenow=$self->gettime();
	my $output=`racadm -r $drac_ip -u $username -p '$password' raid resetconfig:$vdtype`;
	my $exit_status=`echo $?`;
	print OUTFILE "@timenow - $drac_ip - $vdtype - CLEARCONFIG - $output\n";
        print OUTFILE "@timenow - $drac_ip - $vdtype - CLEARCONFIG - Exit Status : $exit_status\n";
        chop($exit_status);
        if($exit_status ne 0)
        {
        	return $exit_status;
        }
	my $return=$self->schedule_job($drac_ip,$username,$password,$vdtype,$vdtype);
        if($return ne  0)
	{
		return $return;
        }

}

## Enabling PXE on a network interface
sub enable_pxe_on_nic{

	my ($self,$drac_ip,$username,$password,$nic_number)=@_;
	my @nics=$self->get_nics($drac_ip,$username,$password);	
	my $temp_nics="@nics";
	my @nic_name=split("\n",$temp_nics);
	

	my @nic_fdds=$self->get_nic_fddn($drac_ip,$username,$password);
	my $temp_fdds="@nic_fdds";
	my @nic_fddn=split("\n",$temp_fdds);

	$nic_name[$nic_number-1]=~ s/^\s+|\s+$//g;
	$nic_fddn[$nic_number-1]=~ s/^\s+|\s+$//g;

	my $target_nic_name=$nic_name[$nic_number-1];
	my $target_nic_fddn=$nic_fddn[$nic_number-1];

	@timenow=$self->gettime();
	my $check_ifset=`racadm -r $drac_ip -u $username -p '$password' get $target_nic_name | grep -i legacybootproto`;
	$check_ifset=~ s/^\s+|\s+$//g;
	chomp($check_ifset);
	if(index($check_ifset, "PXE") != -1)
	{
		print OUTFILE "@timenow - $drac_ip - $target_nic_fddn - PXE already set\n";
		return 0;
	}
	@timenow=$self->gettime();

	my $output=`racadm -r $drac_ip -u $username -p '$password' set $target_nic_name.legacybootproto PXE`;
        my $exit_status=`echo $?`;
        print OUTFILE "@timenow - $drac_ip - $target_nic_fddn - SETPXE - $output\n";
        print OUTFILE "@timenow - $drac_ip - $target_nic_fddn - SETPXE - Exit Status : $exit_status\n";
        chop($exit_status);
        if($exit_status ne 0)
        {
                return $exit_status;
        }
        my $return=$self->schedule_job($drac_ip,$username,$password,$target_nic_fddn,$target_nic_fddn);
        if($return ne  0)
        {
                return $return;
        }	
	
	return 0;

}

## Disabling PXE on a network interface
sub disable_pxe_on_nic{

        my ($self,$drac_ip,$username,$password,$nic_number)=@_;
        my @nics=$self->get_nics($drac_ip,$username,$password);
        my $temp_nics="@nics";
        my @nic_name=split("\n",$temp_nics);


        my @nic_fdds=$self->get_nic_fddn($drac_ip,$username,$password);
        my $temp_fdds="@nic_fdds";
        my @nic_fddn=split("\n",$temp_fdds);

        $nic_name[$nic_number-1]=~ s/^\s+|\s+$//g;
        $nic_fddn[$nic_number-1]=~ s/^\s+|\s+$//g;

        my $target_nic_name=$nic_name[$nic_number-1];
        my $target_nic_fddn=$nic_fddn[$nic_number-1];

        @timenow=$self->gettime();
	my $check_ifset=`racadm -r $drac_ip -u $username -p '$password' get $target_nic_name | grep -i legacybootproto`;
        $check_ifset=~ s/^\s+|\s+$//g;
        chomp($check_ifset);
        if(index($check_ifset, "NONE") != -1)
        {
                print OUTFILE "@timenow - $drac_ip - $target_nic_fddn - PXE already disabled\n";
                return 0;
        }
        @timenow=$self->gettime();

        my $output=`racadm -r $drac_ip -u $username -p '$password' set $target_nic_name.legacybootproto NONE`;
        my $exit_status=`echo $?`;
        print OUTFILE "@timenow - $drac_ip - $target_nic_fddn - SETPXE - $output\n";
        print OUTFILE "@timenow - $drac_ip - $target_nic_fddn - SETPXE - Exit Status : $exit_status\n";
        chop($exit_status);
        if($exit_status ne 0)
        {
                return $exit_status;
        }
        my $return=$self->schedule_job($drac_ip,$username,$password,$target_nic_fddn,$target_nic_fddn);
        if($return ne  0)
        {
                return $return;
        }



}


## Creating Virtual Disks/Raid
sub create_vds{

	my ($self,$drac_ip,$username,$password,$raid_levels,$physical_disks)=@_;
	my @pds=$self->get_pdisks($drac_ip,$username,$password);
	my $temp_pds="@pds";
	my @pdisks=split("\n",$temp_pds);
	
	my @rls=split(":",$raid_levels);
	my $count=0;
	my $pdtype;
	my @pd_array=split(":",$physical_disks);
	foreach my $rl(@rls)
	{
		my $raid_string="";
		my @pdr=split(",",$pd_array[$count]);
		foreach my $pdnum(@pdr)
		{
			if($raid_string eq "")
			{
				my @pdtypes=split(":",$pdisks[$pdnum]);
                		$pdtype=$pdtypes[2];
				$pdtype=~ s/^\s+|\s+$//g;
				$pdisks[$pdnum]=~ s/^\s+|\s+$//g;
				$raid_string=$pdisks[$pdnum];
			}
			else
			{
				$pdisks[$pdnum]=~ s/^\s+|\s+$//g;
				$raid_string=$raid_string.",$pdisks[$pdnum]";

			}
		}
		my $output;
		@timenow=$self->gettime();
		if($rl eq 10)
		{
			$output=`racadm -r $drac_ip -u $username -p '$password' raid createvd:$pdtype -rl r$rl -pdkey:$raid_string -sc 3`;
		}
		else
		{
			$output=`racadm -r $drac_ip -u $username -p '$password' raid createvd:$pdtype -rl r$rl -pdkey:$raid_string`;
		}

		my $exit_status=`echo $?`;
                print OUTFILE "@timenow - $drac_ip - CREATEVD - $output\n";
                print OUTFILE "@timenow - $drac_ip - CREATEVD - Exit Status : $exit_status\n";
                chop($exit_status);
                if($exit_status ne 0)
                {
                        return $exit_status;
                }
		my $return=$self->schedule_job($drac_ip,$username,$password,$pdtype,$pdtype);
		if($return ne  0)
		{
			return $return;
		}
		$count=$count+1;
##Uncomment if you want to do full and slow initilization of RAID

		#my @vds=get_vdisks($drac_ip,$username,$password);
       	 	#my $temp_vds="@vds";
        	#my @vdisks=split("\n",$temp_vds);

        	#my @vdtypes=split(":",$vdisks[0]);
        	#my $vdtype=$vdtypes[1];
        	#$vdtype=~ s/^\s+|\s+$//g;
        	#@timenow=gettime();
		
		#my $vd_fddn=$vdisks[-1];
		#$vd_fddn=~ s/^\s+|\s+$//g;
        	#$output=`racadm -r $drac_ip -u $username -p '$password' raid init:$vd_fddn -speed fast`;
        	#$exit_status=`echo $?`;
        	#print OUTFILE "@timenow - $drac_ip - $vdtype - RAID_INIT - $output";
        	#print OUTFILE "@timenow - $drac_ip - $vdtype - RAID_INIT - Exit Status : $exit_status";
        	#chop($exit_status);
        	#if($exit_status ne 0)
        	#{
                #	return $exit_status;
        	#}
        	#$return=schedule_job($drac_ip,$username,$password,$vdtype,$vdtype);
        	#if($return ne  0)
        	#{
                #	return $return;
        	#}
	
	}


	return 0;
}

## For scheduling a Racadm job
sub schedule_job{


		my ($self,$drac_ip,$username,$password,$vd,$vdtype)=@_;

		my $job_scheduler=`racadm -r $drac_ip -u $username -p '$password' jobqueue create $vdtype`;
                my $exit_status=`echo $?`;
                print OUTFILE  "@timenow - $drac_ip - $vd - JOBQUEUE_CREATE - $job_scheduler\n";
                chomp($exit_status);
                if($exit_status ne 0)
                {
                        return $exit_status;
                }
                my @jid=split("Commit JID = ",$job_scheduler);
                my $job_id=$jid[1];
                chop($job_id);
                $job_id=~ s/^\s+|\s+$//g;
                print OUTFILE  "@timenow - $drac_ip - $vd - JOBQUEUE_CREATE - job ID:$job_id \n";
                print OUTFILE "@timenow - $drac_ip - $vd - JOBQUEUE_CREATE - Exit Status: $exit_status \n";


		@timenow=$self->gettime();
		my $job_status=`racadm -r $drac_ip -u $username -p '$password' jobqueue view -i $job_id | grep \"Message\" |  awk 'BEGIN { FS = \"=\" } ; { print \$2 }'`;
		while ( index($job_status, "scheduled") == -1)
		{
			
			print OUTFILE "@timenow - $drac_ip - $vd - Waiting for $job_id to be scheduled. Sleeping for 60 s \n";
			sleep(60);
			$job_status=` racadm -r $drac_ip -u $username -p '$password' jobqueue view -i $job_id | grep \"Message\" |  awk 'BEGIN { FS = \"=\" } ; { print \$2 }'`;

		}
		
		@timenow=$self->gettime();

		print OUTFILE "@timenow - $drac_ip - $vd - Scheduled $job_id \n";
		print OUTFILE "@timenow - $drac_ip - Going for Reboot \n";
		my $reboot_status=`racadm -r $drac_ip -u $username -p '$password' serveraction hardreset`;
		$exit_status=`echo $?`;
		chomp($exit_status);
		if($exit_status eq 0)
		{
			print OUTFILE "@timenow - $drac_ip - Rebooting successfully \n";
		}
		else
		{

			print OUTFILE "@timenow - $drac_ip - Rebooting Failed \n";
		}
		
		print OUTFILE "@timenow - $drac_ip - Sleeping for 120s for reboot to complete \n";
		sleep(120);
		@timenow=$self->gettime();
		$job_status=` racadm -r $drac_ip -u $username -p '$password' jobqueue view -i $job_id | grep \"Message\" |  awk 'BEGIN { FS = \"=\" } ; { print \$2 }'`;
                while ( ( index($job_status, "completed") == -1 ) and ( index($job_status, "failed") == -1 ) )
                {

                        print OUTFILE "@timenow - $drac_ip - $vd - Waiting for $job_id to be completed. Sleeping for 60 s \n";
                        sleep(60);
                        $job_status=` racadm -r $drac_ip -u $username -p '$password' jobqueue view -i $job_id | grep \"Message\" |  awk 'BEGIN { FS = \"=\" } ; { print \$2 }'`;

                }
		@timenow=$self->gettime();
		if(index($job_status, "failed") != -1)
                {
                        print OUTFILE  "@timenow - $drac_ip - $vd -$job_id - FAILED \n";
                        return 255;
                }


		print OUTFILE "@timenow - $drac_ip - $vd - Completed $job_id \n";

		return 0;


}


## Format the time in any way you want
sub gettime()
{
        my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =localtime(time);
        my @month = qw( Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec );
        my @week=qw(Sun Mon Tue Wed Thu Fri Sat);
        my $yr=1900+$year;
        if($hour<10)
        {
                $hour="0"."$hour";
        }
        if($min<10)
        {
                $min="0"."$min";
        }
        if($sec<10)
        {
                $sec="0"."$sec";
        }

        my $date_time="$week[$wday]"." "."$month[$mon]"." "."$mday"." "."$hour".":"."$min".":"."$sec"." "."IST"." "."$yr";
        return  $date_time;



}

1;
