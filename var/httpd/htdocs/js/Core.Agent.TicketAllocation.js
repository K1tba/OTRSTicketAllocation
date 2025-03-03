// --
// Copyright (C) 2001-2020 OTRS AG, https://otrs.com/
// --
// This software comes with ABSOLUTELY NO WARRANTY. For details, see
// the enclosed file COPYING for license information (GPL). If you
// did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
// --
"use strict";

var Core = Core || {};
Core.Agent = Core.Agent || {};

 /**
 * @namespace Core.Agent.TicketAllocation
 * @memberof Core.Agent.Admin
 * @author OTRS AG
 * @description
 *      This namespace contains the special module functions for AgentCompetenceLevel.
 */
 Core.Agent.TicketAllocation = (function (TargetNS) {

    /**
     * @name Init
     * @memberof Core.Agent.TicketAllocation
     * @function
     * @description
     *      This function initializes the special module functions
     */
    TargetNS.Init = function () {
        Core.UI.Table.InitTableFilter($('#FilterQueues'), $('#Queues'));
        Core.UI.Table.InitTableFilter($('#FilterUsers'), $('#Users'));
    };

    Core.Init.RegisterNamespace(TargetNS, 'APP_MODULE');

    return TargetNS;
}(Core.Agent.TicketAllocation || {}));
