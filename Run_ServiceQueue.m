%[text] # Run samples of the ServiceQueue simulation William Greeley & Zach Bricker 
%[text] Collect statistics and plot histograms along the way.
PictureFolder = "Pictures";
mkdir(PictureFolder); %[output:3135166a]
%%
%[text] ## Set up
%[text] We'll measure time in hours
%[text] Arrival rate: 2 per hour
lambda = 2;
%[text] Departure (service) rate: 1 per 20 minutes, so 3 per hour
mu = 3;
%[text] Number of serving stations
s = 1;
%[text] Run many samples of the queue.
NumSamples = 20;
%[text] Each sample is run up to a maximum time.
MaxTime = 8;
%[text] Make a log entry every so often
LogInterval = 1/60;
%%
%[text] ## Numbers from theory for M/M/1 queue
%[text] Compute `P(1+n)` = $P\_n$ = probability of finding the system in state $n$ in the long term. Note that this calculation assumes $s=1$.
rho = lambda / mu;
P0 = 1 - rho;
nMax = 10;
s = 1;
P = zeros([1, nMax+1]);
P(1) = P0;
for n = 1:nMax
    %P(1+n) = P0 * rho^n;
     if n <= s
        P(1+n) = (1/factorial(n)) * (rho^n) * P0;
    else
        P(1+n) = (1/(factorial(s) * s^(n-s))) * (rho^n) * P0;
    end
end

%[text] Compute Theoretical Values 
% Compute L, Lq, W, Wq 
Lq = rho^2 / (1-rho);
L = Lq + rho;
Wq = Lq / lambda;
W  = L / lambda;
fprintf("\n-- Theroetical Values (Baseline) ---\n"); %[output:62052388]
fprintf("L = %.4f\n", L); %[output:3c85f130]
fprintf("Lq = %.4f\n", Lq); %[output:37089a9b]
fprintf("W = %.4f hours (%.2f minutes) \n", W, W*60); %[output:11b30dc4]
fprintf("Wq = %.4f hours (%.2f minutes) \n", Wq, Wq*60); %[output:0fde40ac]
%[text] 
%%
%[text] ## Run simulation samples
%[text] This is the most time consuming calculation in the script, so let's put it in its own section.  That way, we can run it once, and more easily run the faster calculations multiple times as we add features to this script.
%[text] Reset the random number generator.  This causes MATLAB to use the same sequence of pseudo-random numbers each time you run the script, which means the results come out exactly the same.  This is a good idea for testing purposes.  Under other circumstances, you probably want the random numbers to be truly unpredictable and you wouldn't do this.
rng("default");
%[text] We'll store our queue simulation objects in this list.
QSamples = cell([NumSamples, 1]);
%[text] The statistics come out weird if the log interval is too short, because the log entries are not independent enough.  So the log interval should be long enough for several arrival and departure events happen.
for SampleNum = 1:NumSamples %[output:group:0ca66f46]
    if mod(SampleNum, 10) == 0
        fprintf("%d ", SampleNum);
    end
    if mod(SampleNum, 100) == 0
        fprintf("\n");
    end
    q = ServiceQueue( ... %[output:0724858a]
        ArrivalRate=lambda, ... %[output:0724858a]
        DepartureRate=mu, ... %[output:0724858a]
        NumServers=s, ... %[output:0724858a]
        LogInterval=LogInterval); %[output:0724858a]
    q.schedule_event(Arrival(q.InterArrivalDist(), Customer(1)));
    run_until(q, MaxTime);
    QSamples{SampleNum} = q;
end %[output:group:0ca66f46]
%%
%[text] ## Collect measurements of how many customers are in the system
%[text] `Count how many customers are in the system at each log entry for each sample run.  There are two ways to do this.  You only have to do one of them.`
%[text] ### Option one: Use a for loop.
NumInSystemSamples = cell([NumSamples, 1]);
for SampleNum = 1:NumSamples
    q = QSamples{SampleNum};
    % Pull out samples of the number of customers in the queue system. Each
    % sample run of the queue results in a column of samples of customer
    % counts, because tables like q.Log allow easy extraction of whole
    % columns like this.
    NumInSystemSamples{SampleNum} = q.Log.NumWaiting + q.Log.NumInService;
end
%[text] ### Option two: Map a function over the cell array of ServiceQueue objects.
%[text] `The` @(q) ... expression is shorthand for a function that takes a `ServiceQueue` as input, names it `q`, and computes the sum of two columns from its log.  The `cellfun` function applies that function to each item in `QSamples`. The option `UniformOutput=false` tells `cellfun` to produce a cell array rather than a numerical array.
NumInSystemSamples = cellfun( ...
    @(q) q.Log.NumWaiting + q.Log.NumInService, ...
    QSamples, ...
    UniformOutput=false);
%[text] ## Join numbers from all sample runs.
%[text] vertcat `is short for "vertical concatenate", meaning it joins a bunch of arrays vertically, which in this case results in one tall column.`
NumInSystem = vertcat(NumInSystemSamples{:});
%[text] MATLAB-ism: When you pull multiple items from a cell array, the result is a "comma-separated list" rather than some kind of array.  Thus, the above means
%[text] `NumInSystem = vertcat(NumInSystemSamples{1}, NumInSystemSamples{2}, ...)`
%[text] which concatenates all the columns of numbers in NumInSystemSamples into one long column.
%[text] This is roughly equivalent to "splatting" in Python, which looks like `f(*args)`.
%%
%[text] ## Pictures and stats for number of customers in system
%[text] Print out mean number of customers in the system.
meanNumInSystem = mean(NumInSystem);
fprintf("Mean number in system: %f\n", meanNumInSystem);
%[text] Make a figure with one set of axes.
fig = figure();
t = tiledlayout(fig,1,1);
ax = nexttile(t);
%[text] MATLAB-ism: Once you've created a picture, you can use `hold` to cause further plotting functions to work with the same picture rather than create a new one.
hold(ax, "on");
%[text] Start with a histogram.  The result is an empirical PDF, that is, the area of the bar at horizontal index n is proportional to the fraction of samples for which there were n customers in the system.  The data for this histogram is counts of customers, which must all be whole numbers.  The option BinMethod="integers" means to use bins $(-0.5, 0.5), (0.5, 1.5), \\dots$ so that the height of the first bar is proportional to the count of 0s in the data, the height of the second bar is proportional to the count of 1s, etc. MATLAB can choose bins automatically, but since we know the data consists of whole numbers, it makes sense to specify this option so we get consistent results.
h = histogram(ax, NumInSystem, Normalization="probability", BinMethod="integers");
%[text] Plot $(0, P\_0), (1, P\_1), \\dots$.  If all goes well, these dots should land close to the tops of the bars of the histogram.
plot(ax, 0:nMax, P, 'o', MarkerEdgeColor='k', MarkerFaceColor='r');
%[text] Add titles and labels and such.
title(ax, "Number of customers in the system");
xlabel(ax, "Count");
ylabel(ax, "Probability");
legend(ax, "simulation", "theory");
%[text] Set ranges on the axes. MATLAB's plotting functions do this automatically, but when you need to compare two sets of data, it's a good idea to use the same ranges on the two pictures.  To start, you can let MATLAB choose the ranges automatically, and just know that it might choose very different ranges for different sets of data.  Once you're certain the picture content is correct, choose an x range and a y range that gives good results for all sets of data.  The final choice of ranges is a matter of some trial and error.  You generally have to do these commands *after* calling `plot` and `histogram`.
%[text] This sets the vertical axis to go from $0$ to $0.2$.
ylim(ax, [0, 0.2]);
%[text] This sets the horizontal axis to go from $-1$ to $21$.  The histogram will use bins $(-0.5, 0.5), (0.5, 1.5), \\dots$ so this leaves some visual breathing room on the left.
xlim(ax, [-1, 21]);
%[text] `MATLAB-ism: You have to wait a couple of seconds for those settings to take effect or` `exportgraphics` will screw up the margins.
pause(2);
%[text] Save the picture.
exportgraphics(fig, PictureFolder + filesep + "Number in system histogram.pdf");
exportgraphics(fig, PictureFolder + filesep + "Number in system histogram.svg");
%%
%[text] ## Collect measurements of how long customers spend in the system
%[text] This is a rather different calculation because instead of looking at log entries for each sample `ServiceQueue`, we'll look at the list of served  customers in each sample `ServiceQueue`.
%[text] ### Option one: Use a for loop.
TimeInSystemSamples = cell([NumSamples, 1]);
for SampleNum = 1:NumSamples
    q = QSamples{SampleNum};
    % The next command has many parts.
    %
    % q.Served is a row vector of all customers served in this particular
    % sample.
    % The ' on q.Served' transposes it to a column.
    %
    % The @(c) ... expression below says given a customer c, compute its
    % departure time minus its arrival time, which is how long c spent in
    % the system.
    %
    % cellfun(@(c) ..., q.Served') means to compute the time each customer
    % in q.Served spent in the system, and build a column vector of the
    % results.
    %
    % The column vector is stored in TimeInSystemSamples{SampleNum}.
    TimeInSystemSamples{SampleNum} = ...
        cellfun(@(c) c.DepartureTime - c.ArrivalTime, q.Served');
end

%[text] ### Option two: Use `cellfun` twice.
%[text] The outer call to `cellfun` means do something to each ServiceQueue object in `QSamples`.  The "something" it does is to look at each customer in the `ServiceQueue` object's list `q.Served` and compute the time it spent in the system.
TimeInSystemSamples = cellfun( ...
    @(q) cellfun(@(c) c.DepartureTime - c.ArrivalTime, q.Served'), ...
    QSamples, ...
    UniformOutput=false);
%[text] ### Join them all into one big column.
TimeInSystem = vertcat(TimeInSystemSamples{:});
%%
%[text] ## Pictures and stats for time customers spend in the system
%[text] Print out mean time spent in the system.
meanTimeInSystem = mean(TimeInSystem);
fprintf("Mean time in system: %f\n", meanTimeInSystem);
%[text] Make a figure with one set of axes.
fig = figure();
t = tiledlayout(fig,1,1);
ax = nexttile(t);
%[text] This time, the data is a list of real numbers, not integers.  The option `BinWidth=...` means to use bins of a particular width, and choose the left-most and right-most edges automatically.  Instead, you could specify the left-most and right-most edges explicitly.  For instance, using `BinEdges=0:0.5:60` means to use bins $(0, 0.5), (0.5, 1.0), \\dots$
h = histogram(ax, TimeInSystem, Normalization="probability", BinWidth=5/60);
%[text] Add titles and labels and such.
title(ax, "Total time customers spend in the system");
xlabel(ax, "Time");
ylabel(ax, "Probability");
%[text] Set ranges on the axes.
ylim(ax, [0, 0.2]);
xlim(ax, [0, 2.0]);
%[text] Wait for MATLAB to catch up.
pause(2);
%[text] Save the picture.
exportgraphics(fig, PictureFolder + filesep + "Time in system histogram.pdf");
exportgraphics(fig, PictureFolder + filesep + "Time in system histogram.svg");
%[text] ## Number of customers waiting in the queue
NumWaitingSamples = cellfun( ...
    @(q) q.Log.NumWaiting, ...
    QSamples, ...
    UniformOutput=false);

% Join numbers from all sample runs
NumWaiting = vertcat(NumWaitingSamples{:});

% Print mean and plot
meanNumWaiting = mean(NumWaiting);
fprintf("Mean number waiting in queue: %f\n", meanNumWaiting);

fig_waiting_count = figure();
t_waiting_count = tiledlayout(fig_waiting_count, 1, 1);
ax_waiting_count = nexttile(t_waiting_count);

histogram(ax_waiting_count, NumWaiting, Normalization="probability", BinMethod="integers");

title(ax_waiting_count, "Number of Customers Waiting in Queue");
xlabel(ax_waiting_count, "Count");
ylabel(ax_waiting_count, "Probability");
xlim(ax_waiting_count, [-1, 15]); % Adjusted based on queue likely being shorter than total system

pause(2);
exportgraphics(fig_waiting_count, PictureFolder + filesep + "Number waiting histogram.pdf");
exportgraphics(fig_waiting_count, PictureFolder + filesep + "Number waiting histogram.svg");
%[text] ## Calculate the wait times and service times 

% I will use queue logic (max of arrival or previous departure) to find when service starts.
TimeWaitingSamples = cell([NumSamples, 1]);
TimeInServiceSamples = cell([NumSamples, 1]);

for SampleNum = 1:NumSamples
    q = QSamples{SampleNum};
    
    % Skip if no customers were served in this sample
    if isempty(q.Served)
        continue; 
    end
    
    % Extract arrays of arrival and departure times 
    arrivals = cellfun(@(c) c.ArrivalTime, q.Served');
    departures = cellfun(@(c) c.DepartureTime, q.Served');
    
    num_served = length(arrivals);
    service_starts = zeros(num_served, 1);
    
    % First customer starts service immediately upon arrival
    service_starts(1) = arrivals(1);
    
    % Subsequent customers start when they arrive OR when the previous leaves
    for i = 2:num_served
        service_starts(i) = max(arrivals(i), departures(i-1));
    end
    
    % Calculate the metrics
    TimeWaitingSamples{SampleNum} = service_starts - arrivals;
    TimeInServiceSamples{SampleNum} = departures - service_starts;
end

% Join numbers from all sample runs into long columns
TimeWaiting = vertcat(TimeWaitingSamples{:});
TimeInService = vertcat(TimeInServiceSamples{:});


%[text] ## Histogram for time spent waiting in queue
meanTimeWaiting = mean(TimeWaiting);
fprintf("Mean time waiting in queue: %f hours\n", meanTimeWaiting);
fig_waiting_time = figure();
t_waiting_time = tiledlayout(fig_waiting_time, 1, 1);
ax_waiting_time = nexttile(t_waiting_time);

histogram(ax_waiting_time, TimeWaiting, Normalization="probability", BinWidth=5/60);
title(ax_waiting_time, "Time Spent Waiting in the Queue");
xlabel(ax_waiting_time, "Time (Hours)");
ylabel(ax_waiting_time, "Probability");
xlim(ax_waiting_time, [0, 1.5]);

pause(2);
exportgraphics(fig_waiting_time, PictureFolder + filesep + "Time waiting histogram.pdf");
exportgraphics(fig_waiting_time, PictureFolder + filesep + "Time waiting histogram.svg");
%[text] 
%[text] ## Histogram for time spent being served
meanTimeInService = mean(TimeInService);
fprintf("Mean time in service: %f hours\n", meanTimeInService);

fig_service_time = figure();
t_service_time = tiledlayout(fig_service_time, 1, 1);
ax_service_time = nexttile(t_service_time);

histogram(ax_service_time, TimeInService, Normalization="probability", BinWidth=5/60);
title(ax_service_time, "Time Spent Being Served");
xlabel(ax_service_time, "Time (Hours)");
ylabel(ax_service_time, "Probability");
xlim(ax_service_time, [0, 1.0]);

pause(2);
exportgraphics(fig_service_time, PictureFolder + filesep + "Time being served histogram.pdf");
exportgraphics(fig_service_time, PictureFolder + filesep + "Time being served histogram.svg");
%[text] ## The count of customers served per shift 
CustomersServedPerShift = cellfun( ...
    @(q) length(q.Served), ...
    QSamples);

meanCustomersServed = mean(CustomersServedPerShift);
fprintf("Mean customers served per shift: %f\n", meanCustomersServed);

fig_served_shift = figure();
t_served_shift = tiledlayout(fig_served_shift, 1, 1);
ax_served_shift = nexttile(t_served_shift);


histogram(ax_served_shift, CustomersServedPerShift, Normalization="probability", BinMethod="integers");

title(ax_served_shift, "Count of Customers Served Per Shift");
xlabel(ax_served_shift, "Number of Customers");
ylabel(ax_served_shift, "Probability");

xlim(ax_served_shift, [0, 30]); 
ylim(ax_served_shift, [0, 0.2]);

pause(2);
exportgraphics(fig_served_shift, PictureFolder + filesep + "Customers served per shift histogram.pdf");
exportgraphics(fig_served_shift, PictureFolder + filesep + "Customers served per shift histogram.svg");
%[text] Compute the average value
% Calculate the averages from the simulation
L_sim = mean(NumInSystem);
Lq_sim = mean(NumWaiting);
W_sim = mean(TimeInSystem);
Wq_sim = mean(TimeWaiting);

% Print results
fprintf("L  = %.4f\n", L_sim);
fprintf("Lq = %.4f\n", Lq_sim);
fprintf("W  = %.4f hours (%.2f minutes)\n", W_sim, W_sim * 60);
fprintf("Wq = %.4f hours (%.2f minutes)\n", Wq_sim, Wq_sim * 60);

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"onright","rightPanelPercent":6.9}
%---
%[output:3135166a]
%   data: {"dataType":"warning","outputData":{"text":"Warning: Directory already exists."}}
%---
%[output:62052388]
%   data: {"dataType":"text","outputData":{"text":"\n-- Theroetical Values (Baseline) ---\n","truncated":false}}
%---
%[output:3c85f130]
%   data: {"dataType":"text","outputData":{"text":"L = 2.0000\n","truncated":false}}
%---
%[output:37089a9b]
%   data: {"dataType":"text","outputData":{"text":"Lq = 1.3333\n","truncated":false}}
%---
%[output:11b30dc4]
%   data: {"dataType":"text","outputData":{"text":"W = 1.0000 hours (60.00 minutes) \n","truncated":false}}
%---
%[output:0fde40ac]
%   data: {"dataType":"text","outputData":{"text":"Wq = 0.6667 hours (40.00 minutes) \n","truncated":false}}
%---
%[output:0724858a]
%   data: {"dataType":"error","outputData":{"errorType":"runtime","text":"makedist requires one of the following:\n  <a href=\"matlab:matlab.internal.addons.launchers.showExplorer('ErrorRecovery', 'identifier', 'SO', 'focused', 'makedist');\">Simulink Design Optimization<\/a>\n  <a href=\"matlab:matlab.internal.addons.launchers.showExplorer('ErrorRecovery', 'identifier', 'ST', 'focused', 'makedist');\">Statistics and Machine Learning Toolbox<\/a>\n\nError in <a href=\"matlab:matlab.lang.internal.introspective.errorDocCallback('ServiceQueue', '\/Users\/zachbricker\/Documents\/GitHub\/Queueing-simulation-urgent-care\/ServiceQueue.m', 117)\" style=\"font-weight:bold\">ServiceQueue<\/a> (<a href=\"matlab: opentoline('\/Users\/zachbricker\/Documents\/GitHub\/Queueing-simulation-urgent-care\/ServiceQueue.m',117,0)\">line 117<\/a>)\n                makedist(\"Exponential\", mu=1\/obj.ArrivalRate);\n                ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^"}}
%---
