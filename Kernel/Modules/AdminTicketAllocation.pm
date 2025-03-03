# --
# Copyright (C) 2001-2020 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::Modules::AdminTicketAllocation;

use strict;
use warnings;

use Kernel::Language qw(Translatable);

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

    my ( %GetParam, %Errors );
    for my $Parameter (qw(QueueID NewQueueID Limit CompetenceLevel ContinueAfterSave)) {
        $GetParam{$Parameter} = $ParamObject->GetParam( Param => $Parameter );
    }

    # get array params
    for my $Parameter (qw(StateIDs LimitStateIDs ResponsibleIDs)) {
        if ( $ParamObject->GetArray( Param => $Parameter ) ) {
            @{ $GetParam{$Parameter} } = $ParamObject->GetArray( Param => $Parameter );
        }
    }

    # ------------------------------------------------------------ #
    # change
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
            TemplateFile => 'AdminTicketAllocation',
            Data         => \%GetParam,
        );
        $Output .= $LayoutObject->Footer();

        return $Output;
    }

    # ------------------------------------------------------------ #
    # change action
    # ------------------------------------------------------------ #
    elsif ( $Self->{Subaction} eq 'ChangeAction' ) {

        # challenge token check for write action
        $LayoutObject->ChallengeTokenCheck();

        # check needed data
        for my $Needed (qw(QueueID NewQueueID StateIDs Limit LimitStateIDs)) {
            if ( !$GetParam{$Needed} ) {
                $Errors{ $Needed . 'Invalid' } = 'ServerError';
            }
        }

        # if no errors occurred
        if ( !%Errors ) {

            if ( $GetParam{NewQueueID} != $GetParam{QueueID} ) {
                $Kernel::OM->Get('Kernel::System::TicketAllocation')->TicketAllocationDelete(
                    QueueID => $GetParam{QueueID},
                );
            }

            # update preferences
            my $Success = $Kernel::OM->Get('Kernel::System::TicketAllocation')->TicketAllocationSet(
                QueueID         => $GetParam{NewQueueID},
                StateIDs        => $GetParam{StateIDs},
                CompetenceLevel => $GetParam{CompetenceLevel} || 0,
                Limit           => $GetParam{Limit},
                LimitStateIDs   => $GetParam{LimitStateIDs},
                ResponsibleIDs  => $GetParam{ResponsibleIDs},
            );

            if ( $Success ) {

                # if the user would like to continue editing the queue, just redirect to the edit screen
                if (
                    defined $GetParam{ContinueAfterSave}
                    && ( $GetParam{ContinueAfterSave} eq '1' )
                    )
                {
                    return $LayoutObject->Redirect(
                        OP => "Action=$Self->{Action};Subaction=Change;QueueID=$GetParam{NewQueueID};Notification=Update"
                    );
                }
                else {

                    # otherwise return to overview
                    return $LayoutObject->Redirect( OP => "Action=$Self->{Action};Notification=Update" );
                }
            }
        }

        # something has gone wrong
        my $Output = $LayoutObject->Header();
        $Output .= $LayoutObject->NavigationBar();

        $Self->_Edit(
            Action => 'Change',
            Errors => \%Errors,
            %GetParam,
        );

        $Output .= $LayoutObject->Output(
            TemplateFile => 'AdminTicketAllocation',
            Data         => \%GetParam,
        );
        $Output .= $LayoutObject->Footer();

        return $Output;
    }

    # ------------------------------------------------------------ #
    # add
    # ------------------------------------------------------------ #
    elsif ( $Self->{Subaction} eq 'Add' ) {

        my $Output = $LayoutObject->Header();
        $Output .= $LayoutObject->NavigationBar();

        $Self->_Edit(
            Action => 'Add',
            %GetParam,
        );

        $Output .= $LayoutObject->Output(
            TemplateFile => 'AdminTicketAllocation',
            Data         => \%GetParam,
        );
        $Output .= $LayoutObject->Footer();

        return $Output;
    }

    # ------------------------------------------------------------ #
    # add action
    # ------------------------------------------------------------ #
    elsif ( $Self->{Subaction} eq 'AddAction' ) {

        # challenge token check for write action
        $LayoutObject->ChallengeTokenCheck();

        # check needed data
        for my $Needed (qw(NewQueueID StateIDs Limit LimitStateIDs)) {
            if ( !$GetParam{$Needed} ) {
                $Errors{ $Needed . 'Invalid' } = 'ServerError';
            }
        }

        # if no errors occurred
        if ( !%Errors ) {

            # update preferences
            my $Success = $Kernel::OM->Get('Kernel::System::TicketAllocation')->TicketAllocationSet(
                QueueID         => $GetParam{NewQueueID},
                StateIDs        => $GetParam{StateIDs},
                CompetenceLevel => $GetParam{CompetenceLevel} || 0,
                Limit           => $GetParam{Limit},
                LimitStateIDs   => $GetParam{LimitStateIDs},
                ResponsibleIDs  => $GetParam{ResponsibleIDs},
            );

            if ( $Success ) {
                return $LayoutObject->Redirect(
                    OP => "Action=$Self->{Action};Subaction=Change;QueueID=$GetParam{NewQueueID}",
                );
            }
        }

        # something has gone wrong
        my $Output = $LayoutObject->Header();
        $Output .= $LayoutObject->NavigationBar();

        $Self->_Edit(
            Action => 'Add',
            Errors => \%Errors,
            %GetParam,
        );

        $Output .= $LayoutObject->Output(
            TemplateFile => 'AdminTicketAllocation',
            Data         => \%Param,
        );
        $Output .= $LayoutObject->Footer();

        return $Output;
    }

    # ------------------------------------------------------------ #
    # delete action
    # ------------------------------------------------------------ #
    elsif ( $Self->{Subaction} eq 'DeleteAction' ) {

        # challenge token check for write action
        $LayoutObject->ChallengeTokenCheck();

        # check needed data
        if ( !$GetParam{QueueID} ) {
            $Errors{'QueueIDInvalid'} = 'ServerError';
        }

        # if no errors occurred
        if ( !%Errors ) {

            # update preferences
            $Kernel::OM->Get('Kernel::System::TicketAllocation')->TicketAllocationDelete(
                QueueID => $GetParam{QueueID},
            );

            return $LayoutObject->Redirect(
                OP => "Action=AdminTicketAllocation;",
            );
        }

        # something has gone wrong
        my $Output = $LayoutObject->Header();
        $Output .= $LayoutObject->NavigationBar();

        $Self->_Edit(
            Action => 'Add',
            Errors => \%Errors,
            %GetParam,
        );

        $Output .= $LayoutObject->Output(
            TemplateFile => 'AdminTicketAllocation',
            Data         => \%GetParam,
        );
        $Output .= $LayoutObject->Footer();

        return $Output;
    }

    # ------------------------------------------------------------ #
    # overview
    # ------------------------------------------------------------ #
    else {

        my $Output = $LayoutObject->Header();
        $Output .= $LayoutObject->NavigationBar();

        # check if queue preferences are available
        if ( !$Kernel::OM->Get('Kernel::Config')->Get('QueuePreferences') ) {
            $Output .= $LayoutObject->Notify(
                Priority => 'Warning',
                Info     => 'To work with this form, at least one \'QueuePreferences\' parameter must be enabled in the system settings!',
            );
        }

        $Self->_Overview();

        $Output .= $LayoutObject->Output(
            TemplateFile => 'AdminTicketAllocation',
            Data         => \%GetParam,
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
    my $QueueObject            = $Kernel::OM->Get('Kernel::System::Queue');
    my $UserObject             = $Kernel::OM->Get('Kernel::System::User');

    $LayoutObject->Block(
        Name => 'Overview',
        Data => \%Param,
    );

    $LayoutObject->Block( Name => 'ActionList' );
    $LayoutObject->Block( Name => 'ActionOverview' );

    if ( $Param{QueueID} ) {

        # get allocation data
        my %Queue = $TicketAllocationObject->TicketAllocationGet(
            QueueID => $Param{QueueID},
        );

        # set old data
        $Param{StateIDs}        = $Queue{StateIDs};
        $Param{Limit}           = $Queue{Limit};
        $Param{LimitStateIDs}   = $Queue{LimitStateIDs};
        $Param{CompetenceLevel} = $Queue{CompetenceLevel} ? ' checked="checked"' : '';
        $Param{ResponsibleIDs}  = $Queue{ResponsibleIDs};
    }

    # get all queue
    my %QueueList = $QueueObject->QueueList(
        Valid => 1
    );

    # get all queues that are connected to the ticket allocation
    my @QueueIDs = $TicketAllocationObject->TicketAllocationList();

    QUEUEID:
    for my $QueueID ( @QueueIDs ) {
        next QUEUEID if $Param{QueueID} && $Param{QueueID} == $QueueID;
        delete $QueueList{$QueueID};
    }

    $Param{QueueOption} = $LayoutObject->AgentQueueListOption(
        Data           => \%QueueList,
        Name           => 'NewQueueID',
        SelectedID     => $Param{QueueID} || '',
        OnChangeSubmit => 0,
        Class          => 'Modernize',
    );

    my %StateList = $Kernel::OM->Get('Kernel::System::State')->StateList(
        UserID => 1,
    );

    $Param{StateOption} = $LayoutObject->BuildSelection(
        Data         => \%StateList,
        Name         => 'StateIDs',
        SelectedID   => $Param{StateIDs} || '',
        Multiple     => 1, 
        PossibleNone => 1,
        Translation  => 1,
        Class        => 'Modernize Validate_Required',
    );

    $Param{LimitStateOption} = $LayoutObject->BuildSelection(
        Data         => \%StateList,
        Name         => 'LimitStateIDs',
        SelectedID   => $Param{LimitStateIDs} || '',
        Multiple     => 1, 
        PossibleNone => 1,
        Translation  => 1,
        Class        => 'Modernize Validate_Required',
    );

    my %ResponsibleList = ();
    if ( $Param{QueueID} ) {

        # get group id defined for the given queue id
        my $GroupID = $QueueObject->GetQueueGroupID(
            QueueID => $Param{QueueID},
        );

        # get all users of this group
        %ResponsibleList = $Kernel::OM->Get('Kernel::System::Group')->PermissionGroupGet(
            GroupID => $GroupID,
            Type    => 'rw',
        );

        # delete OTRS user from list responsible
        delete $ResponsibleList{1};

        for my $UserID ( keys %ResponsibleList ) {

            # get user name
            $ResponsibleList{$UserID} = $UserObject->UserName(
                UserID => $UserID,
            );
        }
    }

    $Param{ResponsibleOption} = $LayoutObject->BuildSelection(
        Data         => \%ResponsibleList,
        Name         => 'ResponsibleIDs',
        SelectedID   => $Param{ResponsibleIDs} || '',
        Multiple     => 1, 
        PossibleNone => 1,
        Translation  => 0,
        Class        => 'Modernize',
    );

    $LayoutObject->Block(
        Name => 'OverviewUpdate',
        Data => {
            %Param,
        },
    );

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
    $LayoutObject->Block( Name => 'ActionAdd' );
    $LayoutObject->Block( Name => 'Filter' );

    $LayoutObject->Block(
        Name => 'OverviewResult',
        Data => \%Param,
    );

    my %QueueList = $TicketAllocationObject->TicketAllocationList();

    # error handling
    if ( !%QueueList ) {
        $LayoutObject->Block(
            Name => 'NoDataFoundMsg',
        );
        return 1;
    }

    # get needed object
    my $QueueObject = $Kernel::OM->Get('Kernel::System::Queue');
    my $UserObject  = $Kernel::OM->Get('Kernel::System::User');

    for my $QueueID ( sort keys %QueueList ) {

        # get allocation data
        my %Data = $TicketAllocationObject->TicketAllocationGet(
            QueueID => $QueueID,
        );

        # get queue name
        $Data{QueueName} = $QueueObject->QueueLookup(
            QueueID => $QueueID,
        );

        # get responsible name
        if ( $Data{ResponsibleIDs} ) {
            for my $ResponsibleID ( @{ $Data{ResponsibleIDs} } ) {

                if ( $Data{ResponsibleNames} ) {
                    $Data{ResponsibleNames} .= ', ';
                }

                $Data{ResponsibleNames} .= $UserObject->UserName(
                    UserID => $ResponsibleID,
                );
            }
        }

        $LayoutObject->Block(
            Name => 'OverviewResultRow',
            Data => {
                %Data,
            },
        );
    }

    return 1;
}

1;
