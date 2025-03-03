# --
# Copyright (C) 2001-2020 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Console::Command::Maint::Ticket::AllocationCheck;

use strict;
use warnings;

use parent qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::DB',
    'Kernel::System::Ticket',
    'Kernel::System::TicketAllocation',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Process and allocate tickets based on predefined rules.');

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Process tickets allocation...</yellow>\n");

    # get config for ticket allocation
    my $Config = $Kernel::OM->Get('Kernel::Config')->Get('TicketAllocation');

    if ( !$Config->{WaitPeriod} ) {
        $Self->PrintError("Need WaitPeriod for tickets allocation!\n");
        return $Self->ExitCodeError();
    }

    # get needed objects
    my $DBObject               = $Kernel::OM->Get('Kernel::System::DB');
    my $TicketObject           = $Kernel::OM->Get('Kernel::System::Ticket');
    my $TicketAllocationObject = $Kernel::OM->Get('Kernel::System::TicketAllocation');

    # preparing SQL query for get tickets in the ticket allocation queue
    $DBObject->Prepare(
        SQL => '
            SELECT ticket_id, time
            FROM ticket_allocation_queue
            ORDER BY ticket_id, time',
    );

    my %TicketIDs;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $TicketIDs{ $Row[0] } = $Row[1];
    }

    if ( !%TicketIDs ) {
        $Self->Print("Tickets for allocation have not been found.\n");
        return $Self->ExitCodeOk();
    }

    # process each ticket by ID in ascending order
    TICKETID:
    for my $TicketID ( sort { $a <=> $b } keys %TicketIDs ) {

        # get ticket data
        my %Ticket = $TicketObject->TicketGet(
            TicketID => $TicketID,
            UserID   => 1,
        );

        # if the ticket:
        # 1) is no found
        # 2) is locked
        # 3) is in the closed/merged state,
        # remove the ticket from the ticket allocation queue
        if (
            !%Ticket
            || $Ticket{Lock} eq 'lock'
            || $Ticket{StateType} =~ /closed|removed|merged/i
            )
        {

            # remove the ticket from the allocation queue
            $DBObject->Do(
                SQL  => 'DELETE FROM ticket_allocation_queue WHERE ticket_id = ?',
                Bind => [
                    \$TicketID,
                ],
            );
            next TICKETID;
        }

        my $UserID = $TicketAllocationObject->TicketAllocationUserGet(
            TicketID => $TicketID
        );

        next TICKETID if !$UserID;

        # update the ticket owner
        $TicketAllocationObject->TicketAllocationOwnerSet(
            TicketID         => $TicketID,
            UserID           => $UserID,
            PreResponsibleID => $Ticket{ResponsibleID},
        );

        # remove the ticket from the allocation queue
        $DBObject->Do(
            SQL  => 'DELETE FROM ticket_allocation_queue WHERE ticket_id = ?',
            Bind => [
                \$TicketID,
            ],
        );
    }

    $Self->Print("<green>Done.</green>\n");
    return $Self->ExitCodeOk();
}

1;
