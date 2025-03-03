# --
# Copyright (C) 2001-2020 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::Modules::AgentTicketAllocation;

use strict;
use warnings;

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # Store last entity screen.
    $Kernel::OM->Get('Kernel::System::AuthSession')->UpdateSessionID(
        SessionID => $Self->{SessionID},
        Key       => 'LastScreenEntity',
        Value     => $Self->{RequestedURL},
    );

    # get needed object
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ParamObject  = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $QueueObject  = $Kernel::OM->Get('Kernel::System::Queue');

    my %GetParam;
    for my $Key (qw(QueueID ContinueAfterSave)) {
        $GetParam{$Key} = $ParamObject->GetParam( Param => $Key ) || '';
    }

    # ------------------------------------------------------------ #
    # Change
    # ------------------------------------------------------------ #
    if ( $Self->{Subaction} eq 'Change' ) {

        $GetParam{Queue} = $QueueObject->QueueLookup(
            QueueID => $GetParam{QueueID},
        );

        my $Output = $LayoutObject->Header();
        $Output .= $LayoutObject->NavigationBar();

        $Self->_Edit(
            Action => 'Change',
            %GetParam,
        );

        $Output .= $LayoutObject->Output(
            TemplateFile => 'AgentTicketAllocation',
            Data         => \%GetParam,
        );
        $Output .= $LayoutObject->Footer();

        return $Output;
    }

    # ------------------------------------------------------------ #
    # change action
    # ------------------------------------------------------------ #
    elsif ( $Self->{Subaction} eq 'ChangeAction' ) {

        my @UserIDs = $ParamObject->GetArray( Param => 'Exclude' );

        my %ExcludedUserIDs;
        for my $UserID ( @UserIDs ) {
            $ExcludedUserIDs{ $UserID } = 1;
        }

        # encode perl data structure to JSON string
        my $JSONString = $Kernel::OM->Get('Kernel::System::JSON')->Encode(
            Data => \%ExcludedUserIDs
        );

        # queue pref update db
        my $Success = $Kernel::OM->Get('Kernel::System::Queue')->QueuePreferencesSet(
            QueueID => $GetParam{QueueID},
            Key     => 'TicketAllocationExcludedUserIDs',
            Value   => $JSONString,
            UserID  => 1,
        );

        if ( $Success ) {

            # if the user would like to continue editing the queue, just redirect to the edit screen
            if (
                defined $GetParam{ContinueAfterSave}
                && ( $GetParam{ContinueAfterSave} eq '1' )
                )
            {
                return $LayoutObject->Redirect(
                    OP => "Action=$Self->{Action};Subaction=Change;QueueID=$GetParam{QueueID};Notification=Update"
                );
            }
            else {

                # otherwise return to overview
                return $LayoutObject->Redirect( OP => "Action=$Self->{Action};Notification=Update" );
            }
        }
    }

    # ------------------------------------------------------------ #
    # reset action
    # ------------------------------------------------------------ #
    elsif ( $Self->{Subaction} eq 'ResetAction' ) {

        # queue pref update db
        $Kernel::OM->Get('Kernel::System::Queue')->QueuePreferencesSet(
            QueueID => $GetParam{QueueID},
            Key     => 'TicketAllocationExcludedUserIDs',
            Value   => '',
            UserID  => 1,
        );

        return $LayoutObject->Redirect(
            OP => "Action=$Self->{Action};Subaction=Change;QueueID=$GetParam{QueueID};Notification=Update"
        );
    }

    # ------------------------------------------------------------ #
    # overview
    # ------------------------------------------------------------ #
    else {
        $Self->_Overview();

        my $Output = $LayoutObject->Header();
        $Output .= $LayoutObject->NavigationBar();

        $Output .= $LayoutObject->Output(
            TemplateFile => 'AgentTicketAllocation',
            Data         => \%Param,
        );
        $Output .= $LayoutObject->Footer();

        return $Output;
    }
}

sub _Edit {
    my ( $Self, %Param ) = @_;

    # get needed object
    my $LayoutObject           = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $TicketAllocationObject = $Kernel::OM->Get('Kernel::System::TicketAllocation');
    my $GroupObject            = $Kernel::OM->Get('Kernel::System::Group');
    my $QueueObject            = $Kernel::OM->Get('Kernel::System::Queue');

    $LayoutObject->Block(
        Name => 'Overview',
        Data => \%Param,
    );

    $LayoutObject->Block( Name => 'ActionList' );

    $LayoutObject->Block(
        Name => 'ActionOverview',
        Data => {
            Action => 1,
        }
    );

    $LayoutObject->Block(
        Name => 'ActionReset',
        Data => \%Param,
    );

    $LayoutObject->Block( Name => 'FilterUsers' );

    $LayoutObject->Block(
        Name => 'OverviewUpdate',
        Data => \%Param,
    );

    # get allocation data
    my %Data = $TicketAllocationObject->TicketAllocationGet(
        QueueID => $Param{QueueID},
    );

    my $GroupID = $QueueObject->GetQueueGroupID(
        QueueID => $Param{QueueID}
    );

    # get users list
    my %Users = $GroupObject->PermissionGroupGet(
        GroupID => $GroupID,
        Type    => 'owner',
    );

    # delete OTRS user from list users
    delete $Users{1};

    # remove the person responsible 
    # for ticket allocation from the list of users
    for my $ResponsibleID ( @{ $Data{ResponsibleIDs} } ) {
        delete $Users{ $ResponsibleID };
    }

    # error handling
    if ( !%Users ) {
        return $LayoutObject->Block(
            Name => 'OverviewUpdateRowNoDataFoundMsg'
        );
    }

    my $Config = $Kernel::OM->Get('Kernel::Config')->Get('TicketAllocation');

    for my $UserID ( keys %Users ) {

        my %Groups = $GroupObject->PermissionUserGet(
            UserID => $UserID,
            Type   => 'rw',
        );
        my @Groups = values %Groups;

        for my $Group ( @{ $Config->{GroupNot} } ) {
            if ( grep { $_ eq $Group } @Groups ) {
                delete $Users{$UserID};
                last;
            }
        }
    }

    # get user object
    my $UserObject = $Kernel::OM->Get('Kernel::System::User');

    USERID:
    for my $UserID ( sort keys %Users ) {

        my $Name = $UserObject->UserName(
            UserID => $UserID,
        );

        next USERID if !$Name;

        $LayoutObject->Block(
            Name => 'OverviewUpdateRow',
            Data => {
                ID      => $UserID,
                Name    => $Users{$UserID} . " ($Name)",
                Checked => $Data{ExcludedUserIDs}->{$UserID} ? 'checked' : '',
            }
        );
    }

    return 1;
}

sub _Overview {
    my ( $Self, %Param ) = @_;

    # get needed object
    my $LayoutObject           = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $TicketAllocationObject = $Kernel::OM->Get('Kernel::System::TicketAllocation');

    $LayoutObject->Block(
        Name => 'Overview',
        Data => \%Param,
    );

    $LayoutObject->Block( Name => 'ActionList' );
    $LayoutObject->Block( Name => 'ActionOverview' );
    $LayoutObject->Block( Name => 'FilterQueues' );

    $LayoutObject->Block( Name => 'OverviewResult' );

    my %QueueList = $TicketAllocationObject->TicketAllocationList();

    my @QueueIDs;
    for my $QueueID ( sort keys %QueueList ) {

        # get allocation data
        my %Data = $TicketAllocationObject->TicketAllocationGet(
            QueueID => $QueueID,
        );

        if ( $Data{ResponsibleIDs} ) {
            for my $ResponsibleID ( @{ $Data{ResponsibleIDs} } ) {
                if ( $ResponsibleID == $Self->{UserID} ) {
                    push @QueueIDs, $QueueID;
                    last;
                }
            }
        }
    }

    # error handling
    if ( !@QueueIDs ) {
        $LayoutObject->Block( Name => 'Warning' );
        $LayoutObject->Block( Name => 'OverviewResultRowNoDataFoundMsg' );
        return 1;
    }

    # get queue object
    my $QueueObject = $Kernel::OM->Get('Kernel::System::Queue');

    QUEUEID:
    for my $QueueID ( sort @QueueIDs ) {

        my $QueueName = $QueueObject->QueueLookup(
            QueueID => $QueueID
        );

        next QUEUEID if !$QueueName;

        $LayoutObject->Block(
            Name => 'OverviewResultRow',
            Data => {
                QueueID   => $QueueID,
                QueueName => $QueueName,
            }
        );
    }

    return 1;
}

1;
