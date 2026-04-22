% Run samples of the ServiceQueue simulation William Greeley & Zach Bricker
% Collect statistics and plot histograms along the way.

PictureFolder = "Pictures";
mkdir(PictureFolder);

%% Set up
% We'll measure time in hours
% Arrival rate: 2 per hour
lambda = 2;

% Departure (service) rate: 1 per 20 minutes, so 3 per hour
mu = 3;

% Number of serving stations
s = 1;

% Run many samples of the queue
NumSamples = 20;

% Each sample is run up to a maximum time
MaxTime = 8;

% Make a log entry every so often
LogInterval = 1/60;

% Theta (renege rate)
% Mean renege time is 15 minutes = 0.25 hours, so theta = 4 per hour
theta = 4;

NMax = 10;
%% Reneging theory
%P0 = 1 / hypergeom([1], [mu/theta], lambda/theta);

%NMax = 5;
%P = zeros(NMax+1, 1);
%P(1) = P0;

%for j = 1:NMax
%    P(j+1) = (lambda / (mu + (j-1)*theta)) * P(j);
%end

%pi_s_theory = (mu * (1 - P(1))) / lambda;

%fprintf("\n--- RENEGING THEORY ---\n");
%for j = 0:NMax
%    fprintf("P%d = %.4f\n", j, P(j+1));
%end
%fprintf("pi_s = %.4f\n", pi_s_theory);

%% Run simulation samples
% Reset the random number generator so results are reproducible
rng("default");

% Store queue simulation objects here
QSamples = cell(NumSamples, 1);

for SampleNum = 1:NumSamples
    if mod(SampleNum, 10) == 0
        fprintf("%d ", SampleNum);
    end
    if mod(SampleNum, 100) == 0
        fprintf("\n");
    end

    q = ServiceQueueRenege( ...
    'ArrivalRate', lambda, ...
    'DepartureRate', mu, ...
    'RenegeRate', theta, ...
    'NumServers', s, ...
    'LogInterval', LogInterval);

    q.schedule_event(Arrival(q.InterArrivalDist(), Customer(1)));
    run_until(q, MaxTime);
    QSamples{SampleNum} = q;
end
fprintf("\n");

%% Collect measurements of how many customers are in the system
NumInSystemSamples = cellfun( ...
    @(q) q.Log.NumWaiting + q.Log.NumInService, ...
    QSamples, ...
    UniformOutput=false);

NumInSystem = vertcat(NumInSystemSamples{:});

%% Pictures and stats for number of customers in system
meanNumInSystem = mean(NumInSystem);
fprintf("Mean number in system: %f\n", meanNumInSystem);

fig = figure();
t = tiledlayout(fig,1,1);
ax = nexttile(t);

hold(ax, "on");
histogram(ax, NumInSystem, Normalization="probability", BinMethod="integers");
%plot(ax, 0:NMax, P, 'o', MarkerEdgeColor='k', MarkerFaceColor='r');

title(ax, "Number of customers in the system");
xlabel(ax, "Count");
ylabel(ax, "Probability");
legend(ax, "simulation", "theory");

ylim(ax, [0, 0.2]);
xlim(ax, [-1, 21]);

pause(2);
exportgraphics(fig, PictureFolder + filesep + "Number in system histogram.pdf");
exportgraphics(fig, PictureFolder + filesep + "Number in system histogram.svg");

%% Collect measurements of how long customers spend in the system
TimeInSystemSamples = cellfun( ...
    @(q) cellfun(@(c) c.DepartureTime - c.ArrivalTime, q.Served'), ...
    QSamples, ...
    UniformOutput=false);

TimeInSystem = vertcat(TimeInSystemSamples{:});

%% Pictures and stats for time customers spend in the system
meanTimeInSystem = mean(TimeInSystem);
fprintf("Mean time in system: %f\n", meanTimeInSystem);

fig = figure();
t = tiledlayout(fig,1,1);
ax = nexttile(t);

histogram(ax, TimeInSystem, Normalization="probability", BinWidth=5/60);

title(ax, "Total time customers spend in the system");
xlabel(ax, "Time");
ylabel(ax, "Probability");

ylim(ax, [0, 0.2]);
xlim(ax, [0, 2.0]);

pause(2);
exportgraphics(fig, PictureFolder + filesep + "Time in system histogram.pdf");
exportgraphics(fig, PictureFolder + filesep + "Time in system histogram.svg");

%% Number of customers waiting in the queue
NumWaitingSamples = cellfun( ...
    @(q) q.Log.NumWaiting, ...
    QSamples, ...
    UniformOutput=false);

NumWaiting = vertcat(NumWaitingSamples{:});

meanNumWaiting = mean(NumWaiting);
fprintf("Mean number waiting in queue: %f\n", meanNumWaiting);

fig_waiting_count = figure();
t_waiting_count = tiledlayout(fig_waiting_count, 1, 1);
ax_waiting_count = nexttile(t_waiting_count);

histogram(ax_waiting_count, NumWaiting, Normalization="probability", BinMethod="integers");

title(ax_waiting_count, "Number of Customers Waiting in Queue");
xlabel(ax_waiting_count, "Count");
ylabel(ax_waiting_count, "Probability");
xlim(ax_waiting_count, [-1, 15]);

pause(2);
exportgraphics(fig_waiting_count, PictureFolder + filesep + "Number waiting histogram.pdf");
exportgraphics(fig_waiting_count, PictureFolder + filesep + "Number waiting histogram.svg");

%% Calculate the wait times and service times
TimeWaitingSamples = cell(NumSamples, 1);
TimeInServiceSamples = cell(NumSamples, 1);

for SampleNum = 1:NumSamples
    q = QSamples{SampleNum};

    if isempty(q.Served)
        continue;
    end

    arrivals = cellfun(@(c) c.ArrivalTime, q.Served');
    departures = cellfun(@(c) c.DepartureTime, q.Served');

    num_served = length(arrivals);
    service_starts = zeros(num_served, 1);

    service_starts(1) = arrivals(1);

    for i = 2:num_served
        service_starts(i) = max(arrivals(i), departures(i-1));
    end

    TimeWaitingSamples{SampleNum} = service_starts - arrivals;
    TimeInServiceSamples{SampleNum} = departures - service_starts;
end

TimeWaiting = vertcat(TimeWaitingSamples{:});
TimeInService = vertcat(TimeInServiceSamples{:});

%% Histogram for time spent waiting in queue
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

%% Histogram for time spent being served
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

%% The count of customers served per shift
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

%% Count of customers that reneged per shift
CustomersRenegedPerShift = cellfun( ...
    @(q) length(q.Reneged), ...
    QSamples);

meanCustomersReneged = mean(CustomersRenegedPerShift);
fprintf("Mean customers reneged per shift: %f\n", meanCustomersReneged);

fig_reneged_shift = figure();
t_reneged_shift = tiledlayout(fig_reneged_shift, 1, 1);
ax_reneged_shift = nexttile(t_reneged_shift);

histogram(ax_reneged_shift, CustomersRenegedPerShift, ...
    Normalization="probability", BinMethod="integers");

title(ax_reneged_shift, "Count of Customers that Reneged Per Shift");
xlabel(ax_reneged_shift, "Number of Customers");
ylabel(ax_reneged_shift, "Probability");

pause(2);
exportgraphics(fig_reneged_shift, PictureFolder + filesep + "Customers reneged per shift histogram.pdf");
exportgraphics(fig_reneged_shift, PictureFolder + filesep + "Customers reneged per shift histogram.svg");

%% Fraction reneged and simulated pi_s
TotalCustomersPerShift = CustomersServedPerShift + CustomersRenegedPerShift;
FractionRenegedPerShift = CustomersRenegedPerShift ./ TotalCustomersPerShift;

meanFractionReneged = mean(FractionRenegedPerShift);
pi_s_sim = 1 - meanFractionReneged;

fprintf("Average fraction reneged: %.4f\n", meanFractionReneged);
fprintf("Simulated pi_s: %.4f\n", pi_s_sim);

%% Simulation averages
L_sim = mean(NumInSystem);
Lq_sim = mean(NumWaiting);
W_sim = mean(TimeInSystem);
Wq_sim = mean(TimeWaiting);

fprintf("\n--- SIMULATION AVERAGES WITH RENEGING ---\n");
fprintf("L  = %.4f\n", L_sim);
fprintf("Lq = %.4f\n", Lq_sim);
fprintf("W  = %.4f hours (%.2f minutes)\n", W_sim, W_sim * 60);
fprintf("Wq = %.4f hours (%.2f minutes)\n", Wq_sim, Wq_sim * 60);
fprintf("Mean time in service = %.4f hours\n", meanTimeInService);
fprintf("Mean customers served per shift = %.4f\n", meanCustomersServed);
fprintf("Mean customers reneged per shift = %.4f\n", meanCustomersReneged);
fprintf("Average fraction reneged = %.4f\n", meanFractionReneged);
%fprintf("Theoretical pi_s = %.4f\n", pi_s_theory);
fprintf("Simulated pi_s = %.4f\n", pi_s_sim);