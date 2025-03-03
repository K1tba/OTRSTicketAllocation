# --
# Copyright (C) 2001-2020 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Ticket::Event::TicketAllocation;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::DB',
    'Kernel::System::Log',
    'Kernel::System::Ticket',
    'Kernel::System::TicketAllocation',
    'Kernel::System::Web::Request',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Data Event UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }
    for (qw(TicketID)) {
        if ( !$Param{Data}->{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_ in Data!"
            );
            return;
        }
    }

    return 1 if $Param{Event} !~ /TicketCreate|TicketQueueUpdate|TicketStateUpdate/;

    # get needed objects
    my $TicketObject           = $Kernel::OM->Get('Kernel::System::Ticket');
    my $TicketAllocationObject = $Kernel::OM->Get('Kernel::System::TicketAllocation');

    my %QueueList = $TicketAllocationObject->TicketAllocationList();

    return 1 if !%QueueList;

    # get ticket data
    my %Ticket = $TicketObject->TicketGet(
        TicketID      => $Param{Data}->{TicketID},
        UserID        => $Param{UserID},
        DynamicFields => 0,
    );

    return if !%Ticket;

    return 1 if !$QueueList{ $Ticket{QueueID} };

    # get config for ticket allocation
    my $Config = $Kernel::OM->Get('Kernel::Config')->Get('TicketAllocation');

    if ( $Config->{NotAutoAssignWhenNewOwnerIsSelected} ) {

        # get param object
        my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');

        # if the NewUserID or NewOwnerID parameter is present,
        # it means that the owner has already been selected,
        # and we cancel the automatic allocation.
        if (
            $ParamObject->GetParam( Param => 'NewUserID' )
            || $ParamObject->GetParam( Param => 'NewOwnerID' )
            )
        {
            return 1;
        }
    }

    my %Data = $TicketAllocationObject->TicketAllocationGet(
        QueueID => $Ticket{QueueID},
    );

    if ( $Param{Event} eq 'TicketStateUpdate' ) {

        my %LimitStateIDs = map { $_ => 1 } @{ $Data{LimitStateIDs} };

        # if the override flag (ReAssign) is enabled
        # and the current status of the application does not match in StateCount,
        # and the previous state is present in StateCount,
        # then we check the availability of tickets with the specified statuses and owners.
        if (
            $Config->{ReAssign}
            && !$LimitStateIDs{ $Ticket{StateID} }
            && $LimitStateIDs{ $Param{Data}->{OldTicketData}->{StateID} }
            )
        {

            # counting tickets that meet the search conditions
            my $Count = $TicketObject->TicketSearch(
                Result   => 'COUNT',
                QueueIDs => [ $Ticket{QueueID} ],
                StateIDs => [ @{ $Data{LimitStateIDs} } ] ,
                OwnerIDs => [ $Ticket{OwnerID} ],
                UserID   => 1,
            );

            if ( $Count == 0 ) {

                # search for a suitable ticket
                my ( $TicketID ) = $TicketObject->TicketSearch(
                    Result   => 'ARRAY',
                    QueueIDs => [ $Ticket{QueueID} ],
                    StateIDs => [ @{ $Data{StateIDs} } ],
                    OwnerIDs => [ 1 ],
                    SortBy   => [ 'Priority', 'Age' ],
                    OrderBy  => [ 'Down', 'Up' ],
                    UserID   => 1,
                    Limit    => 1,
                );

                if ( $TicketID ) {

                    # set the owner of the ticket
                    $TicketAllocationObject->TicketAllocationOwnerSet(
                        TicketID         => $TicketID,
                        UserID           => $Ticket{OwnerID},
                        PreResponsibleID => $Ticket{ResponsibleID},
                    );
                }
            }
        }

        return 1;
    }

    my %StateIDs = map { $_ => 1 } @{ $Data{StateIDs} };

    # if the current status of the ticket is not supported for allocation,
    # then we terminate the execution
    return 1 if !$StateIDs{ $Ticket{StateID} };

    # get the UserID for allocation
    my $UserID = $TicketAllocationObject->TicketAllocationUserGet(
        TicketID => $Param{Data}->{TicketID},
        Event    => 1,
    );

    if ( $UserID ) {

        # set the owner of the ticket
        $TicketAllocationObject->TicketAllocationOwnerSet(
            TicketID         => $Param{Data}->{TicketID},
            UserID           => $UserID,
            PreResponsibleID => $Ticket{ResponsibleID},
        );

        # delete ticket from the allocation queue
        return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
            SQL  => 'DELETE FROM ticket_allocation_queue WHERE ticket_id = ?',
            Bind => [
                \$Param{Data}->{TicketID},
            ],
        );
    }

    return 1;
}

1;
                                   	