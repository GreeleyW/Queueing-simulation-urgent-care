# Queue Simulation Part 3: Allowing Customers to Renege
**Author:** Dr. Garrett Mitchener 
**Editors:** William Greeley & Zach Bricker 

A queueing simulation in MATLAB that models an urgent care with a renege feature where patients can get out of the line after entering. 
This is an M/M/1 queue simulation.
The overall architecture is event driven.
The main classes are `ServiceQueue` and `ServiceQueueRenege`.
They maintain a list of events, ordered by the time that they occur.
There is one `Arrival` scheduled at any time that represents the arrival of the next customer.
When a customer arrives and has to wait, a `Renege` event is scheduled.
When a customer reaches the front of the waiting queue, they can be moved to a service station.
Once a customer moves into a service slot, a `Departure` event for that customer is scheduled.
If the `Renege` event happens before the customer reaches a service slot, they run out of patience and leave the line early.
There should be one `Departure` event scheduled for each busy service station.
There is one `RecordToLog` scheduled at any time that represents the next time statistics will be added to the log table.

We have included two literate scripts:
`Run_ServiceQueue.m` runs the baseline system without reneging.
`Run_ServiceQueueRenege.m` runs the new simulation to show how customer impatience reduces overall wait times.

FYI: The use of "queueing" rather than "queuing" is for consistency with the textbook.