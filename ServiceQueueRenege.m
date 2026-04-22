classdef ServiceQueueRenege < handle
    % ServiceQueueRenege
    % Queue simulation with reneging.

    properties (SetAccess = public)
        % Arrival rate (per hour)
        ArrivalRate = 10;

        % Service/departure rate (per hour)
        DepartureRate = 12;

        % Number of servers
        NumServers = 1;

        % Time between log entries
        LogInterval = 1/60;

        % Renege rate (per hour)
        RenegeRate = 5;
    end

    properties (SetAccess = private)
        % Current simulation time
        Time = 0;

        % Random-sampling functions
        InterArrivalDist;
        ServiceDist;
        RenegeDist;

        % Server state
        ServerAvailable;
        Servers;

        % Event queue
        Events;

        % Customer lists
        Waiting = {};
        Served = {};
        Reneged = {};

        % Log table
        Log = table(Size=[0, 5], ...
            VariableNames={'Time','NumWaiting','NumInService','NumServed','NumReneged'}, ...
            VariableTypes={'double','int64','int64','int64','int64'});
    end

    methods
        function obj = ServiceQueueRenege(varargin)
            % Constructor using name/value pairs, e.g.
            % ServiceQueueRenege('ArrivalRate',2,'DepartureRate',3,...)

            if mod(length(varargin), 2) ~= 0
                error('Inputs must be name/value pairs.');
            end

            for k = 1:2:length(varargin)
                name = varargin{k};
                value = varargin{k+1};

                if ~ischar(name) && ~isstring(name)
                    error('Parameter names must be strings or character vectors.');
                end

                name = char(name);

                if isprop(obj, name)
                    obj.(name) = value;
                else
                    error('Unknown parameter name: %s', name);
                end
            end

            % Initialize distributions
            obj.InterArrivalDist = @() (-log(rand) / obj.ArrivalRate);
            obj.ServiceDist = @() (-log(rand) / obj.DepartureRate);
            obj.RenegeDist = @() (-log(rand) / obj.RenegeRate);

            % Initialize system state
            obj.ServerAvailable = repelem(true, obj.NumServers);
            obj.Servers = cell([1, obj.NumServers]);
            obj.Events = PriorityQueue({}, @(x) x.Time);

            % First log event
            schedule_event(obj, RecordToLog(obj.LogInterval));
        end

        function obj = run_until(obj, MaxTime)
            while obj.Time <= MaxTime
                handle_next_event(obj);
            end
        end

        function schedule_event(obj, event)
            assert(event.Time >= obj.Time, "Event happens in the past");
            push(obj.Events, event);
        end

        function handle_next_event(obj)
            assert(~is_empty(obj.Events), "No unhandled events");

            event = pop_first(obj.Events);
            assert(event.Time >= obj.Time, "Event happens in the past");

            obj.Time = event.Time;
            visit(event, obj);
        end

        function handle_arrival(obj, arrival)
            % Record arrival time
            c = arrival.Customer;
            c.ArrivalTime = obj.Time;

            % Add customer to waiting list
            obj.Waiting{end+1} = c;

            % If all servers busy, schedule reneging
            if ~any(obj.ServerAvailable)
                renege_time = obj.RenegeDist();
                renege_event = Renege(obj.Time + renege_time, c.Id);
                schedule_event(obj, renege_event);
            end

            % Schedule next arrival
            next_customer = Customer(c.Id + 1);
            inter_arrival_time = obj.InterArrivalDist();
            next_arrival = Arrival(obj.Time + inter_arrival_time, next_customer);
            schedule_event(obj, next_arrival);

            % See if someone can start service
            advance(obj);
        end

        function handle_departure(obj, departure)
            j = departure.ServerIndex;

            assert(~obj.ServerAvailable(j), "Service station j must be occupied");
            assert(obj.Servers{j} ~= false, "There must be a customer in service station j");

            customer = obj.Servers{j};
            customer.DepartureTime = departure.Time;

            obj.Served{end+1} = customer;

            obj.Servers{j} = false;
            obj.ServerAvailable(j) = true;

            advance(obj);
        end

        function begin_serving(obj, j, customer)
            customer.BeginServiceTime = obj.Time;

            obj.Servers{j} = customer;
            obj.ServerAvailable(j) = false;

            service_time = obj.ServiceDist();
            obj.schedule_event(Departure(obj.Time + service_time, j));
        end

        function advance(obj)
            while ~isempty(obj.Waiting)
                [x, j] = max(obj.ServerAvailable);

                if x
                    customer = obj.Waiting{1};
                    obj.Waiting(1) = [];
                    begin_serving(obj, j, customer);
                else
                    break;
                end
            end
        end

        function handle_record_to_log(obj, ~)
            record_log(obj);
            schedule_event(obj, RecordToLog(obj.Time + obj.LogInterval));
        end

        function n = count_customers_in_system(obj)
            NumWaiting = length(obj.Waiting);
            NumInService = obj.NumServers - sum(obj.ServerAvailable);
            n = NumWaiting + NumInService;
        end

        function record_log(obj)
            NumWaiting = length(obj.Waiting);
            NumInService = obj.NumServers - sum(obj.ServerAvailable);
            NumServed = length(obj.Served);
            NumReneged = length(obj.Reneged);

            obj.Log(end+1, :) = {obj.Time, NumWaiting, NumInService, NumServed, NumReneged};
        end

        function handle_renege(obj, renege)
            customer_id = renege.CustomerId;

            % If customer is still waiting, remove them and mark reneged
            for i = 1:length(obj.Waiting)
                if obj.Waiting{i}.Id == customer_id
                    customer = obj.Waiting{i};
                    obj.Reneged{end+1} = customer;
                    obj.Waiting(i) = [];
                    return;
                end
            end

            % If not found, do nothing (they may already be in service or served)
        end
    end
end