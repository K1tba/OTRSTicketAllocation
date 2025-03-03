# --
# Copyright (C) 2001-2020 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::Language::ru_OTRSTicketAllocation;

use strict;
use warnings;
use utf8;

sub Data {
    my $Self = shift;

    # Template: AdminCompetenceLevel
    $Self->{Translation}->{'Ticket Allocation Management'} = 'Управление распределением заявок';
    $Self->{Translation}->{'Add Ticket Allocation'} = 'Добавить распределение заявок';
    $Self->{Translation}->{'Edit Ticket Allocation'} = 'Редактировать распределение заявок';
    $Self->{Translation}->{'Tickets limit'} = 'Лимит заявок';
    $Self->{Translation}->{'Ticket limit count status'} = 'Состояние для подсчета лимита заявок';
    $Self->{Translation}->{'Responsible for ticket allocation'} = 'Ответственные за распределените заявок';
    $Self->{Translation}->{'Invalid value for the ticket limit!'} = 'Неверное значение для лимита заявок!';
#    $Self->{Translation}->{''} = '';

    # Template: AgentCompetenceLevel
    $Self->{Translation}->{'Warning! You do not have permissions to access this module.'} = 'Внимание! У вас нет прав доступа к этому модулю.';
    $Self->{Translation}->{'Reset all settings excluding'} = 'Сбросить все настройки исключений';
    $Self->{Translation}->{'Exclude'} = 'Исключить';
#    $Self->{Translation}->{''} = '';

    # Perl Module: Kernel/Modules/AdminCompetenceLevel.pm
#    $Self->{Translation}->{''} = '';

    # Perl Module: Kernel/Modules/AgentCompetenceLevel.pm
#    $Self->{Translation}->{''} = '';

    # SysConfig
    $Self->{Translation}->{'Ticket Allocation'} = 'Распределение заявок';
    $Self->{Translation}->{'Manage allocations tickets in queues.'} = 'Управление распределением заявок в очередях.';
    $Self->{Translation}->{'Overview of ticket allocation.'} = 'Обзор распределения заявок.';
    $Self->{Translation}->{'Automatically allocation of tickets.'} = 'Автоматическое распределение заявок.';
    $Self->{Translation}->{'Checks tickets queued for allocation and distributes to members of the queue.'} = 'Проверяет билеты, стоящие в очереди на распределение, и распределяет их между участниками очереди.';
    $Self->{Translation}->{'Groups of agents not involved in ticket allocation.'} = 'Группы агентов, не участвующих в распределении заявок.';
    $Self->{Translation}->{'Waiting time for a repeat attempt to allocate a ticket (minutes).'} = 'Время ожидания повторной попытки распределения заявки (минуты).';
    $Self->{Translation}->{'Perform ticket allocation only working hours.'} = 'Выполнять распределение заявок только в рабочее время.';
    $Self->{Translation}->{'Use only the queue calendar, not the SLA calendar.'} = 'Использовать только календарь очередей, а не календарь SLA.';
    $Self->{Translation}->{'Lock ticket whenever there is a allocation.'} = 'Блокировать заявку при каждом распределении.';
    $Self->{Translation}->{'Change ticket status whenever there is a allocation.'} = 'Изменять статус заявки каждый раз, когда происходит распределение.';
    $Self->{Translation}->{'Skip agent when ticket limit is reached.'} = 'Пропустите агента, когда достигнут лимит заявок.';
    $Self->{Translation}->{'Tickets reallocation.'} = 'Перераспределение заявок.';
    $Self->{Translation}->{'Not ticket allocation when new owner is selected.'} = 'Не распределять заявки при выборе нового владельца.';
    $Self->{Translation}->{'Count agent tickets only in allocation queue.'} = 'Учитывайте билеты агентов только в очереди на распределение.';
#    $Self->{Translation}->{''} = '';

    push @{ $Self->{JavaScriptStrings} // [] }, (
    );

}

1;
