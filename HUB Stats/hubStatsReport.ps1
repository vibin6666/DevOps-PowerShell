<#
	This report will gather log information and present it in an HTML format. 
	It gets its stats by leveraging exloganalyzer and formats the reports accordingly
	
	Make sure to download it and put it in your c:\script directory! - http://archive.msdn.microsoft.com/ExLogAnalyzer/Release/ProjectReleases.aspx?ReleaseId=3628
	
	Example html report in same directory.
	
	Last modified 11/29/10 GF
#>

#Add exchange pssnapin
	Add-PSSnapin Microsoft.Exchange.Management.PowerShell.E2010 -ErrorAction:SilentlyContinue

	
function execute-Reports
{
<#EXAMPLE::
ExLogAnalyzer.exe -StartTimeLocal 2010-11-14T00:12:46.955Z -msgtrkinputpath "\\hub001\c$\Program Files\Microsoft\Exchange Server\V14\Tra
nsportRoles\Logs\MessageTracking;\\hub002\c$\Program Files\Microsoft\Exchange
 Server\V14\TransportRoles\Logs\MessageTracking;\\hubR001\c$\Program Files\Mi
crosoft\Exchange Server\V14\TransportRoles\Logs\MessageTracking;\\hubR002\c$\
Program Files\Microsoft\Exchange Server\V14\TransportRoles\Logs\MessageTracking"
#>

#get and format start and end time. We are parsing yesterdays data
	$date = Get-Date 
	$date = $date.AddDays(-1)
	
	[string]$strStartDate = $date.Month.ToString() +"/"+ $date.Day +"/"+ $date.Year + " 12:00:01 AM"
	[string]$strEndDate = $date.Month.ToString() +"/"+ $date.Day +"/"+ $date.Year + " 11:59:59 PM"

	#Get all hub servers
	$htServers = Get-TransportServer
	$count = ($htServers.count-1)
	
	#Add all hubs to the input path
	foreach ($hub in $htServers)
		{
			#Check for the last server to be added. It CAN NOT have a ; at the end
			if ($hub.name -eq $htServers[$count].name)
				{$msgtrkInputPath += "\\" +$hub.name+ "\c$\Program Files\Microsoft\Exchange Server\V14\TransportRoles\Logs\MessageTracking"}
			else
				{$msgtrkInputPath += "\\" +$hub.name+ "\c$\Program Files\Microsoft\Exchange Server\V14\TransportRoles\Logs\MessageTracking;"}
		}
		
	#contruct string and run program
	Set-Location "C:\Scripts\ExLogAnalyzer"
	$command = "C:\Scripts\ExLoganalyzer\ExLogAnalyzer.exe -StartTimeUtc '" +$strStartDate+ "' -EndTimeUtc '" +$strEndDate+ "' -msgtrkinputpath '" +$msgtrkInputPath+ "'"
	Invoke-Expression $command
	
	if ($?)
		{
		return "success"
		}
	else
		{
		return $returns
		}
}

function create-htmlHeader
{
$date = Get-Date

$global:HTML = @"
<html xmlns='http://www.w3.org/1999/xhtml'>
			<head>
			<meta http-equiv='Content-Type' content='text/html; charset=iso-8859-1' />
			<title>HUB STATS Report</title>
			</head>
			<H2><font color=green>HUB Statistic Report</font></H2>
			<body><font face='verdana' size='3'>
			This report ran on $date
			<HR />
			Jump to : <A HREF ='#HRC'>HUB Receive Connector | </A><A HREF ='#RDS'>Recipient | </A><A HREF ='#SDS'>Sender Distribution | </A><A HREF ='#MDS'>Message Size Distribution | </A><A HREF ='#T25R'>Top 25 Recipients | </A><A HREF ='#T25SD'>Top 25 Senders by delivery | </A><A HREF ='#T25SS'>Top 25 Senders by submit | </A>
			
			<HR />
"@ 
			
}

function add-ReceiveSummary
{
<#
Overview:
Analyzes the distribution of the sources for the messages received by a server or a set of servers.
Columns:
ServerName – The name of the server that received the message.
Source – component / connector - e.g. “SMTP (df-gwy-07\From Internet)”.
Client – The IP address of the client that sent the message (previous server).
MsgCount – The number of messages that match the above criteria.
AvgBytes – The average size of the messages that match the above criteria.
#>
$data = Import-Csv "C:\Scripts\ExLogAnalyzer\Reports\MsgTrk\MsgTrkReceive.csv"

	$HTMLsnippet = "
	<CENTER><A NAME='#HRC'><H2>Top 10 HUB Receive Connectors</H2>
				<table cellspacing='2' border='2' align='center' >
	  						<tr bgcolor=gray>
								<th><FONT COLOR=white>Server</font></th>
								<th><FONT COLOR=white>Source</font></th>
								<th><FONT COLOR=white>Client</font></th>
								<th><FONT COLOR=white>Msg Count</font></th>
								<th><FONT COLOR=white>Average KB</font></th>
							</tr>
	" 
	
	$i=0
	
	
	while ($i -lt 10)
		{
		
		$rawKB = ($data[$i].AvgBytes/1024)
		$KB = "{0:N2}" -f $rawKB
		$HTMLsnippet += "<tr><td>" +$data[$i].ServerName+ "</td><td bgcolor=#cccccc>" +$data[$i].Source+ "</td><td>" +$data[$i].Client+ "</td><td bgcolor=#cccccc>" +$data[$i].MsgCount+ "</td><td>" +$KB+ "</td></tr>"
		$i++
		}
		
		#find total message count
		$msgCount = 0
		
		foreach ($entry in $data)
			{
			$msgCount += $entry.MsgCount
			}
		
		$HTMLsnippet += "<TR bgcolor=#000000><TD><FONT COLOR='yellow'>TOTAL Msgs</FONT></TD><TD></TD><TD></TD><TD><FONT COLOR='yellow'>$msgCount</FONT></TD><TD></TD></TR></table><H5><FONT COLOR=blue>Note: This table shows us where our incoming/internal messages are coming from.</FONT></H5></CENTER><hr />"
		
		$global:HTML +=$HTMLsnippet
}

function add-RecipientDistrbution
{
<#Overview:
Provides an analysis of the recipient load distribution based on number of messages delivered to their mailboxes.
Columns:
ReceivedMsgRange - 1-20 msgs, 21-40 msgs, 41-80 msgs, 81-120 msgs, 121+ msgs.
Count – The number of recipients that fall into the ReceivedMsgRange range.
Percent – The % of total recipients in this bucket.
Percentile – The % of total recipients in this bucket of a lighter bucket.
#>
$data = Import-Csv "C:\Scripts\ExLogAnalyzer\Reports\MsgTrk\MsgTrkRecipientsDistribution.csv"

	$HTMLsnippet = "
	<BR><CENTER><A NAME='#RDS'><H2>Recipient Distribution Statistics</H2>
				<table cellspacing='2' border='2' align='center' >
	  						<tr bgcolor=gray>
								<th><FONT COLOR=white>Received Msg Range</font></th>
								<th><FONT COLOR=white>Count</font></th>
								<th><FONT COLOR=white>Percent</font></th>
								<th><FONT COLOR=white>Percentile</font></th>
							</tr>
	" 
	
	foreach ($entry in $data)
		{
		$HTMLsnippet += "<tr><td>" +$entry.ReceivedMsgRange+ "</td><td bgcolor=#cccccc>" +$entry.Count+ "</td><td>" +$entry.Percent+ "</td><td bgcolor=#cccccc>" +$entry.Percentile+ "</td><td>" +$KB+ "</td></tr>"
		}
		
		$HTMLsnippet += "</table><H5><FONT COLOR=blue>Note: This table lets us know how many emails are received by each mailbox and categorizes them into size ranges.</FONT></H5></CENTER><hr />"

		$global:HTML +=$HTMLsnippet

}

function add-SenderbySubmitDistribution
{
<#Overview:
Provides an analysis of the sender load distribution based on number of messages sent from their mailboxes.
Columns:
SentMsgRange - 1-5 msgs, 6-10 msgs, 11-20 msgs, 21-30 msgs, 31+ msgs.
Count – The number of senders within this bucket.
Percent – The % of senders within this bucket.
Percentile – The percentile of senders within or below this bucket.
#>

$data = Import-Csv "C:\Scripts\ExLogAnalyzer\Reports\MsgTrk\MsgTrkSendersBySubmitDistribution.csv"

	$HTMLsnippet = "
	<BR><CENTER><A NAME='#SDS'><H2>Sender Distribution Statistics</H2>
				<table cellspacing='2' border='2' align='center' >
	  						<tr bgcolor=gray>
								<th><FONT COLOR=white>Sent Msg Range</font></th>
								<th><FONT COLOR=white>Count</font></th>
								<th><FONT COLOR=white>Percent</font></th>
								<th><FONT COLOR=white>Percentile</font></th>
							</tr>
	" 
	
	foreach ($entry in $data)
		{
		$HTMLsnippet += "<tr><td>" +$entry.SentMsgRange+ "</td><td bgcolor=#cccccc>" +$entry.Count+ "</td><td>" +$entry.Percent+ "</td><td bgcolor=#cccccc>" +$entry.Percentile+ "</td><td>" +$KB+ "</td></tr>"
		}
		
		$HTMLsnippet += "</table><H5><FONT COLOR=blue>Note: This table gives us visibility into how many emails are being sent by our mailboxes.</FONT></H5></CENTER><HR />"

		$global:HTML +=$HTMLsnippet
}

function add-SizeDistrbution
{
<#Overview:
Provides an understanding of the message size distribution.
Columns:
SizeRange (1K, 2K, 4K, 8K, 16K, 32K, 64K, 128K, 256K, 512K, 1MB, 2MB, 4MB, 8MB, 16MB, 32MB, 64MB, 128MB, 256MB, 512MB, 1GB, everything else.
Count – The number of messages in this size range.
PercentOnTotal – Percent of total number of messages.
PercentileUnderCurrentSize – The percentile of messages between 0 and the upper limit of the current size range.
#>
$data = Import-Csv "C:\Scripts\ExLogAnalyzer\Reports\MsgTrk\MsgTrkSizeDistribution.csv"

	$HTMLsnippet = "
	<BR><CENTER><A NAME='#SDS'><H2>Message Size Distrbution Statistics</H2>
				<table cellspacing='2' border='2' align='center' >
	  						<tr bgcolor=gray>
								<th><FONT COLOR=white>Size range</font></th>
								<th><FONT COLOR=white>Count</font></th>
								<th><FONT COLOR=white>Percent</font></th>
								<th><FONT COLOR=white>Percentile Under Size</font></th>
							</tr>
	" 
	
	foreach ($entry in $data)
		{
		$HTMLsnippet += "<tr><td>" +$entry.SizeRange+ "</td><td bgcolor=#cccccc>" +$entry.Count+ "</td><td>" +$entry.PercentOnTotal+ "</td><td bgcolor=#cccccc>" +$entry.PercentileUnderCurrentSize+ "</td></tr>"
		}
		
		$HTMLsnippet += "</table><H5><FONT COLOR=blue>Note: This table that categorizes messages based on size. This is meant to give us visibility into our average message size</FONT></H5></CENTER><HR />"

		$global:HTML +=$HTMLsnippet

}

function add-TopRecipients
{
<#Overview:
Generates the top 1000 recipients based on mailbox deliveries.  Messages to the internet are not counted.
Columns:
MailboxServer:
Recipient:
Count: 
Sorting:
Entries are sorted in descending order based on Count.
#>
$data = Import-Csv "C:\Scripts\ExLogAnalyzer\Reports\MsgTrk\MsgTrkTopRecipients.csv"

	$HTMLsnippet = "
	<BR><CENTER><A NAME='#T25R'><H2>Top 25 Recipients</H2>
				<table cellspacing='2' border='2' align='center' >
	  						<tr bgcolor=gray>
								<th><FONT COLOR=white>Mailbox Server</font></th>
								<th><FONT COLOR=white>Recipient</font></th>
								<th><FONT COLOR=white>Count</font></th>
							</tr>
	" 
	
	$i = 0
	while ($i -lt 25)
		{
		$HTMLsnippet += "<tr><td>" +$data[$i].MailboxServer+ "</td><td bgcolor=#cccccc>" +$data[$i].Recipient+ "</td><td>" +$data[$i].Count+ "</td></tr>"
		$i++
		}
		
		$HTMLsnippet += "</table><H5><FONT COLOR=blue>Note: Top 25 recipients.</FONT></H5></CENTER><HR />"

		$global:HTML +=$HTMLsnippet
}

function add-TopSenderByDelivery
{

<#Overview:
Generates the top 1000 senders based on mailbox deliveries.  Messages to the internet are not counted.
Columns:
Sender – The sender email address from which the messages were submitted.  Senders could be external to the organization.
Count – The number of messages delivered from this sender (after DL expansion, etc).
Sorting:
Entries are sorted in descending order based on Count.
#>
$data = Import-Csv "C:\Scripts\ExLogAnalyzer\Reports\MsgTrk\MsgTrkTopSendersByDeliver.csv"

	$HTMLsnippet = "
	<BR><CENTER><A NAME='#T25SD'><H2>Top 25 Senders By Delivery</H2>
				<table cellspacing='2' border='2' align='center' >
	  						<tr bgcolor=gray>
								<th><FONT COLOR=white>Sender</font></th>
								<th><FONT COLOR=white>Count</font></th>
							</tr>
	" 
	
	$i = 0
	while ($i -lt 25)
		{
		$HTMLsnippet += "<tr><td>" +$data[$i].Sender+ "</td><td bgcolor=#cccccc>" +$data[$i].Count+ "</td></tr>"
		$i++
		}
		
		$HTMLsnippet += "</table><H5><FONT COLOR=blue>Note: Top 25 senders into our enviroment</FONT></H5></CENTER><HR />"

		$global:HTML +=$HTMLsnippet
}

function add-TopSenderBySubmit
{
<#Overview:
Generates the top 1000 senders based on mailbox submissions.
Columns:
MailboxServer – The mailbox server from which the messages were submitted.
Sender – The sender mailbox from which the messages were submitted.
Count – The number of messages for the MailboxServer + Sender combination.
Sorting:
Entries are sorted in descending order based on Count.

 #>
$data = Import-Csv "C:\Scripts\ExLogAnalyzer\Reports\MsgTrk\MsgTrkTopSendersBySubmit.csv"

	$HTMLsnippet = "
	<BR><CENTER><A NAME='#T25SS'><H2>Top 25 Senders By Submit</H2>
				<table cellspacing='2' border='2' align='center' >
	  						<tr bgcolor=gray>
								<th><FONT COLOR=white>Mailbox Server</font></th>
								<th><FONT COLOR=white>Sender</font></th>
								<th><FONT COLOR=white>Count</font></th>
							</tr>
	" 
	
	$i = 0
	while ($i -lt 25)
		{
		$HTMLsnippet += "<tr><td>" +$data[$i].MailboxServer+ "</td><td bgcolor=#cccccc>" +$data[$i].Sender+ "</td><td>" +$data[$i].Count+ "</td><tr>"
		$i++
		}
		
		$HTMLsnippet += "</table><H5><FONT COLOR=blue>Note: Table of top 25 senders from our enviroment.</FONT></H5></CENTER><HR />"

		$global:HTML +=$HTMLsnippet
}


################# START OF MAIN ######################

	#execute report
	$result = execute-Reports
	
		if ($result -eq "success")
			{
			#Create HTML header
				create-htmlHeader
			
			#Receive Summary
				add-ReceiveSummary
			
			#Receive Distribution Categorizing
				add-RecipientDistrbution
			
			#Sender by Submition Distrbution
				add-SenderbySubmitDistribution
			
			#Size Distribution 
				add-SizeDistrbution
			
			#Top Recipients
				add-TopRecipients
			
			#Top Senders by delivery
				add-TopSenderByDelivery
			
			#Top Sender by submition
				add-TopSenderBySubmit
			
			#Get date
			$date = Get-Date
			
			#Export HTML
				$dateFormatted = $date.Year.tostring()+"-"+$date.Month.tostring()+"-"+$date.Day.ToString()
				$filename="HUBreport-$dateFormatted"	
				$global:HTML | Out-File c:\temp\$filename.html			
			}
		else
			{
			$Error | Out-File c:\scripts\logs.txt -Append
			}
