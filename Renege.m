classdef Renege < Event
    % Renege Subclass of Event that represents a customer reneging
    % (leaving the queue before being served).

    properties
        CustomerId
    end

    methods
        function obj = Renege(Time, CustomerId)
            arguments
                Time = 0.0;
                CustomerId = 0;
            end

            obj = obj@Event(Time);
            obj.CustomerId = CustomerId;
        end

        function varargout = visit(obj, other)
            [varargout{1:nargout}] = handle_renege(other, obj);
        end
    end
end