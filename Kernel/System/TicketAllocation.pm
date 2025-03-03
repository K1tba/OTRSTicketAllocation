# --
# Copyright (C) 2001-2020 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::TicketAllocation;

use strict;
use warnings;

use List::Util qw(min);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Cache',
    'Kernel::System::DB',
    'Kernel::System::Log',
    'Kernel::System::User',
    'Kernel::System::Group',
    'Kernel::System::Queue',
    'Kernel::System::Ticket',
    'Kernel::System::DateTime',
);

=head1 NAME

Kernel::System::TicketAllocation - ticket allocation lib

=head1 DESCRIPTION

All ticket allocation functions.

=head1 PUBLIC INTERFACE

=head2 new()

Create an object

    my $TicketAllocationObject = $Kernel::OM->Get('Kernel::System::TicketAllocation');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=head2 TicketAllocationGet()

Get the automatic queue assignment data.

    my %Data = $TicketAllocationObject->TicketAllocationGet(
        QueueID => 123,
    );

Returns:

    %Data = (
        QueueID         => 123,
        StateIDs        => [3, 4],
        CompetenceLevel => 1,
        Limit           => 100,
        LimitStateIDs   => [3, 4],
        ResponsibleIDs  => [3, 4],
        ExcludedUserIDs => {...},    
    );
    
    or

    undef if allocation data for queue could not be get

=cut

sub TicketAllocationGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{QueueID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Need QueueID!"
        );
        return;
    }

    # get queue data
    my %Queue = $Kernel::OM->Get('Kernel::System::Queue')->QueueGet(
        ID => $Param{QueueID},
    );

    # return if queue not connected to ticket allocation
    return if !$Queue{TicketAllocation};

    # get needed object
    my $JSONObject = $Kernel::OM->Get('Kernel::System::JSON');

    my $Data = $JSONObject->Decode(
        Data => $Queue{TicketAllocation},
    );

    my %Data = (
        QueueID         => $Param{QueueID},
        StateIDs        => $Data->{StateIDs},
        CompetenceLevel => $Data->{CompetenceLevel} || 0,
        Limit           => $Data->{Limit}           || 0,
        LimitStateIDs   => $Data->{LimitStateIDs},
        ResponsibleIDs  => $Data->{ResponsibleIDs}  || '',
    );

    if ( $Queue{TicketAllocationExcludedUserIDs} ) {
        my $UserIDs = $JSONObject->Decode(
            Data => $Queue{TicketAllocationExcludedUserIDs},
        );

        $Data{ExcludedUserIDs} = $UserIDs || '';
    }

    return %Data;
}

=head2 TicketAllocationSet()

Set queue data to the ticket allocation.

    my $Success = $TicketAllocationObject->TicketAllocationSet(
        QueueID         => 123,
        StateIDs        => [3, 4],
        CompetenceLevel => 1,         # not required -> 0|1 (default 0)
        Limit           => 100,
        LimitStateIDs   => [3, 4],
        ResponsibleIDs  => [3, 4],    # optional, default ''
    );

Returns:

    my $Success = 1;    # or undef if queue could not be set

=cut

sub TicketAllocationSet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(QueueID StateIDs Limit LimitStateIDs)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    # set default if required
    $Param{CompetenceLevel} //= 0;
    $Param{ResponsibleIDs}  //= '';

    # set the params for the allocation of tickets in the queue
    my %Data;
    for my $Key ( qw(StateIDs CompetenceLevel Limit LimitStateIDs ResponsibleIDs) ) {
        $Data{$Key} = $Param{$Key};
    }

    # encode perl data structure to JSON string
    my $JSONString = $Kernel::OM->Get('Kernel::System::JSON')->Encode(
        Data => \%Data
    );

    # queue pref update db
    $Kernel::OM->Get('Kernel::System::Queue')->QueuePreferencesSet(
        QueueID => $Param{QueueID},
        Key     => 'TicketAllocation',
        Value   => $JSONString,
        UserID  => 1,
    );

    # delete cache
    $Kernel::OM->Get('Kernel::System::Cache')->Delete(
        Type => 'TicketAllocation',
        Key  => 'QueueList',
    );

    return 1;
}

=head2 TicketAllocationDelete()

Delete queue data to the ticket allocation.

    my $Success = $TicketAllocationObject->TicketAllocationDelete(
        QueueID => 123,
    );

Returns:

    my $Success = 1;    # or undef if queue could not be delete

=cut

sub TicketAllocationDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{QueueID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Need QueueID!"
        );
        return;
    }

    for my $Key (qw(TicketAllocation TicketAllocationExcludedUserIDs)) {

        # queue pref update db
        $Kernel::OM->Get('Kernel::System::Queue')->QueuePreferencesSet(
            QueueID => $Param{QueueID},
            Key     => $Key,
            Value   => '',
            UserID  => 1,
        );
    }

    # delete cache
    $Kernel::OM->Get('Kernel::System::Cache')->Delete(
        Type => 'TicketAllocation',
        Key  => 'QueueList',
    );

    return 1;
}

=head2 TicketAllocationList()

Get a list of all queues that are connected to the automatic ticket assignment.

    my %QueueList = $TicketAllocationObject->TicketAllocationList();

Returns:

    %QueueList = (
        '1'   => 1,
        '2'   => 1,
        '3'   => 1,
        '...' => 1,
        '123' => 1,
    );

=cut

sub TicketAllocationList {
    my ( $Self, %Param ) = @_;

    # get cache object
    my $CacheObject = $Kernel::OM->Get('Kernel::System::Cache');

    # read cache
    my $Cache = $CacheObject->Get(
        Type => 'TicketAllocation',
        Key  => 'QueueList',
    );
    return %{$Cache} if $Cache;

    # get queue object
    my $QueueObject = $Kernel::OM->Get('Kernel::System::Queue');

    # get queue list
    my %Queues = $QueueObject->QueueList();

    my %QueueList;
    for my $QueueID ( sort keys %Queues ) {

        # get queue data
        my %Queue = $QueueObject->QueueGet(
            ID => $QueueID,
        );

        # check that the queue is connected to the ticket allocation
        if ( $Queue{TicketAllocation} ) {
            $QueueList{ $QueueID } = 1;
        }
    }

    # set cache
    $CacheObject->Set(
        Type => 'TicketAllocation',
        Key  => 'QueueList',
        TTL   => 60 * 60 * 24 * 20,
        Value => \%QueueList,
    );

    return %QueueList;
}

=head2 TicketAllocationUserGet()

Get the UserID of the potential owner of the ticket or
if one could not be found, puts the ticket in the allocation queue

    my $UserID = $TicketAllocationObject->TicketAllocationUserGet(
        TicketID => 123,
        Event    => 1,      # optional, if user id not be found, puts the ticket in the allocation queue
    );

Returns:

    $UserID = 123;    # or undef, if the potential owner could not be found


=cut

sub TicketAllocationUserGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{TicketID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need TicketID!'
        );
        return;
    }

    # get needed object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    # get current system epoch
    my $DateTimeObject = $Kernel::OM->Create('Kernel::System::DateTime');

    # get ticket data
    my %Ticket = $TicketObject->TicketGet( 
        TicketID => $Param{TicketID},
        UserID   => 1,
    );

    my $Config = $ConfigObject->Get('TicketAllocation');

    # allocation only during business hours if required
    if ( $Config->{WorkingTimeOnly} ) {

        # sla id must be deleted if the CalendarByQueueOnly option is enabled in config
        if ( $Ticket{SLAID} && $Config->{CalendarByQueueOnly} ) {
            delete $Ticket{SLAID};
        }

        # get used calendar
        my $Calendar = $TicketObject->TicketCalendarGet(
            QueueID => $Ticket{QueueID},
            SLAID   => $Ticket{SLAID} || '',
        );
    
        # clone DateTimeObject object because it will be changed while calculating
        my $StartTimeObj = $DateTimeObject->Clone();
        my $StopTimeObj  = $DateTimeObject->Clone();

        $StopTimeObj->Add( Seconds => 1 );

        my $WorkingTime = $StartTimeObj->Delta(
            DateTimeObject => $StopTimeObj,
            ForWorkingTime => 1,
            Calendar       => $Calendar,
        )->{AbsoluteSeconds};
    
        return if !$WorkingTime;
    }

    # get ticket allocation data
    my %Queue = $Self->TicketAllocationGet(
        QueueID => $Ticket{QueueID},
    );

    # get group object
    my $GroupObject = $Kernel::OM->Get('Kernel::System::Group');

    # show all users who have rw in the queue group
    my %UserIDs = $GroupObject->PermissionGroupGet(
        GroupID => $Ticket{GroupID},
        Type   => 'rw',
    );

    # delete OTRS user from list users
    delete $UserIDs{1};

    # remove the person responsible 
    # for ticket allocation from the list of users
    if ( $Queue{ResponsibleIDs} ) {
        for my $ResponsibleID ( @{ $Queue{ResponsibleIDs} } ) {
            delete $UserIDs{ $ResponsibleID };
        }
    }

    USERID:
    for my $UserID ( keys %UserIDs ) {

        # delete user from list users if it is in the exclusion list
        if ( $Queue{ExcludedUserIDs}->{$UserID} ) {
            delete $UserIDs{$UserID};
            next USERID;
        }

        # get a list of groups in which the user has rights rw
        my %Groups = $GroupObject->PermissionUserGet(
            UserID => $UserID,
            Type   => 'rw',
        );

        my @Groups = values %Groups;

        for my $Group ( @{ $Config->{GroupNot} } ) {

            # сheck the user for groups that will exclude him from auto-distribution
            if ( grep { $_ eq $Group } @Groups ) {
                delete $UserIDs{$UserID};
                last USERID;
            }
        }
    }

    # get user object
    my $UserObject = $Kernel::OM->Get('Kernel::System::User');

    my %InOfficeUserIDs;
    USERID:
    for my $UserID ( keys %UserIDs ) {

        # get user data
        my %UserData = $UserObject->GetUserData(
            UserID => $UserID,
            Valid  => 1,
        );

        next USERID if !%UserData;

        # building list of users who are present at the workplace
        if ( !$UserData{OutOfOfficeMessage} ) {
            $InOfficeUserIDs{$UserID} = $UserData{UserLogin};
        }
    }

    my $OwnerID;
    if ( %InOfficeUserIDs ) {

        # сheck level of competence, if specified
        if ( $Queue{CompetenceLevel} ) {

            # get сompetence level object
            my $CompetenceLevelObject = $Kernel::OM->Get('Kernel::System::CompetenceLevel');
            for my $UserID ( keys %InOfficeUserIDs ) {
                my $TotalCompetence = $CompetenceLevelObject->CompetenceLevelCalculate(
                    Ticket => \%Ticket,
                    UserID => $UserID,
                );

                # add a level of competence to free users
                $InOfficeUserIDs{$UserID} = $TotalCompetence;
            }

            # sort users by competence level
            my @UserList            = sort { $InOfficeUserIDs{$b} <=> $InOfficeUserIDs{$a} } keys %InOfficeUserIDs;
            my $MaxCompetencieLevel = $InOfficeUserIDs{ $UserList[0] };

            for my $UserID ( keys %InOfficeUserIDs ) {
                if ( $InOfficeUserIDs{$UserID} < $MaxCompetencieLevel ) {

                    # remove users who have a level lower than the maximum
                    delete $InOfficeUserIDs{$UserID};
                }
            }
        }

        my %SearchParam = (
            StateIDs => [ @{ $Queue{LimitStateIDs} } ],
        );

        # add queue id in search param if the CountInAutoAssignQueueOnly option is enabled in config
        if ( $Config->{CountInAutoAssignQueueOnly} ) {
            $SearchParam{QueueIDs} = [ $Ticket{QueueID} ];
        }

        my %FreeUserIDs;
        my @CountTicketFreeUser;
        for my $UserID ( keys %InOfficeUserIDs ) {

            # get the total number of tickets that the user has in progress
            my $Count = $TicketObject->TicketSearch(
                Result   => 'COUNT',
                OwnerIDs => [ $UserID ],
                UserID   => 1,
                %SearchParam,
            ) || 0;

            # add user if Skip Over Limit disabled in config or 
            # the number of tickets is less than defined in the TicketAllocation settings for queue
            if ( !$Config->{SkipOverLimit} || $Count < $Queue{Limit} ) {
                $FreeUserIDs{$UserID} = [ $Count ];
                push @CountTicketFreeUser, $Count;
            }
        }

        if ( %FreeUserIDs ) {

            # finding the minimum number of tickets
            # needed for a fair allocation of tickets
            my %UniqueCountTicketFreeUser  = map { $_, 1 } @CountTicketFreeUser;
            my $MinCountTicket             = min( keys %UniqueCountTicketFreeUser) || 0;

            # finding owner id target for ticket
            for my $UserID ( keys %FreeUserIDs ) {
                if ( $FreeUserIDs{$UserID}->[0] <= $MinCountTicket ) {
                    $OwnerID = $UserID ;
                    last;
                }
            }
        }
    }

    # add ticket in ticket allocation queue if required
    if ( !$OwnerID && $Param{Event} && $Config->{WaitPeriod} ) {

        # build wait period time
        my $WaitTime = $DateTimeObject->ToEpoch() + $Config->{WaitPeriod} * 60 + 50;

        # db insert
        $Kernel::OM->Get('Kernel::System::DB')->Do(
            SQL  => "INSERT INTO ticket_allocation_queue VALUES (?, ?)",
            Bind => [ \$Param{TicketID}, \$WaitTime ],
        );
    }

    return $OwnerID;
}

=head2 TicketAllocationOwnerSet()

To set the ticket owner

    my $Success = $TicketAllocationObject->TicketAllocationOwnerSet(
        TicketID         => 123,
        UserID           => 123,
        PreResponsibleID => 1,      # optional, (0|1) default 0
    );

Return:

   $Success = 1 ( owner has been set )

=cut

sub TicketAllocationOwnerSet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Key (qw(TicketID UserID)) {
        if ( !$Param{$Key} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Key!"
            );
            return;
        }
    }

    # get needed object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    # get config for ticket allocation
    my $Config = $ConfigObject->Get('TicketAllocation');

    # get ticket data
    my %Ticket = $TicketObject->TicketGet(
        TicketID => $Param{TicketID},
        UserID   => 1,
    );

    # search for the oldest and unassigned ticket in the queue
    my ( $TicketID ) = $TicketObject->TicketSearch(
        Result       => 'ARRAY',
        QueueIDs 	 => [ $Ticket{QueueID} ],
        StateType    => [ 'open', 'new' ],
        Locks   	 => [ 'unlock' ],
        OwnerIDs 	 => [ 1 ],
        OrderBy 	 => 'Up',
        Limit        => 1,
        UserID       => 1,
    );

    if ( $TicketID != $Ticket{TicketID} ) {
        $Param{TicketID} = $TicketID;
    }

    # set lock if required
    if ( $Config->{Lock} ) {
        $TicketObject->TicketLockSet(
            TicketID => $Param{TicketID},
            Lock     => 'lock',
            UserID   => 1,
        );
    }

    # set owner
    $TicketObject->TicketOwnerSet(
        TicketID  => $Param{TicketID},
        NewUserID => $Param{UserID},
        UserID    => 1,
    );

    # set responsible if required
    if (
        $ConfigObject->Get('Ticket::Responsible')
        && $ConfigObject->Get('Ticket::ResponsibleAutoSet')
        )
    {
        if ( $Param{PreResponsibleID} && $Param{UserID} != 1 ) {
            $TicketObject->TicketResponsibleSet(
                TicketID           => $Param{TicketID},
                NewUserID          => $Param{UserID},
                SendNoNotification => 1,
                UserID             => 1,
            );
        }
    }

    # set state if required
    if ( $Config->{StateID} ) {
        $TicketObject->TicketStateSet(
            TicketID => $Param{TicketID},
            StateID  => $Config->{StateID},
            UserID   => 1,
        );
    }

    # add history entry
    $TicketObject->HistoryAdd(
        Name         => "\%\%TicketAllocation\%\%",
        HistoryType  => 'Misc',
        TicketID     => $Param{TicketID},
        CreateUserID => 1,
    );

    return 1;
}

1;

=head1 TERMS AND CONDITIONS

This software is part of the OTRS project (L<https://otrs.org/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (GPL). If you
did not receive this file, see L<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
