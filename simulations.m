%% generalized eigendecomposition (linear discriminant) tutorial

% Last modified by Hause Lin 19-10-06 12:40 hauselin@gmail.com

%% set up EEG structure

% simulating 64 channel EEG data
load emptyEEG % mat file containing EEG, leadfield and channel locations
EEG.srate = 500;  % sampling rate (affects EEG.times)

EEG.trials = 200;  % trials to simulate 
EEG.pnts = 1000; % time points per trial
EEG.times = (0:EEG.pnts-1)/EEG.srate; % timepoints in seconds
EEG.data = zeros(EEG.nbchan,EEG.pnts,EEG.trials); % initialize 3D matrix (chan_time_trials)

%% specify neural source/dipole locations (from 2004 locations)

% see lf structure (Gain field is transfer function; projects 2004 dipoles to 64 dimensonal/channel space)
dipoleLoc1 = 109;
dipoleLoc2 = 110;
cfg = []; 
cfg.dipoleIdx = [dipoleLoc1 dipoleLoc2];
% cfg.nrandom = 5;
dipole_project(cfg); % project and plot

%% insert activity waveforms into dipole data

% frequencies of the two dipoles/sources
freq1 = 15;
freq2 = 10;

% specify activity onset time (in seconds) for each source
onset1time = mean(EEG.times); % middle of time series
onset2time = mean(EEG.times) + 0.3; % 0.3s after middle of time series 

% get activity onset time index for each source
onset1idx = dsearchn(EEG.times',onset1time); 
onset2idx = dsearchn(EEG.times',onset2time); 

% create the "inside" of each sine wave (2*pi*fi*time), without sine function 
omega1 = 2*pi*freq1*EEG.times(onset1idx:end)';
omega2 = 2*pi*freq2*EEG.times(onset2idx:end)';

% plot simulated sine waves (no jitter/phase offset)
figure(2)
subplot(211)
plot(EEG.times, [zeros(length(EEG.times) - length(sin(omega1)), 1); sin(omega1)])
title(['source/dipole 1 activity freq: ' num2str(freq1)])
subplot(212)
plot(EEG.times, [zeros(length(EEG.times) - length(sin(omega2)), 1); sin(omega2)])
title(['source/dipole 2 activity freq: ' num2str(freq2)])

% loop over trials to generate data
for ti=1:EEG.trials
    
    % compute neural source waveforms/EEG activity (sine waves with random phase)
    swave1 = sin( omega1 + rand*2*pi ); % non-phase-locked activity
    swave2 = sin( omega2 + rand*2*pi );
    
    % for each dipole/source, add noise at each time point
    dipole_data = randn(EEG.pnts,size(lf.Gain,3))/5;  % divide to scale noise
    
    % add simulated sine wave to random dipole data
    dipole_data(onset1idx:end,dipoleLoc1) = dipole_data(onset1idx:end,dipoleLoc1) + swave1;
    dipole_data(onset2idx:end,dipoleLoc2) = dipole_data(onset2idx:end,dipoleLoc2) + swave2;
    
    % project to scalp (transfer function) and store in EEG.data field
    EEG.data(:,:,ti) = ( dipole_data*squeeze(lf.Gain(:,1,:))' )';
end

%% plot ERPs and topographies

figure(3); clf
subplot(3,4,1:4)
chans2plot = {'Pz', 'P3', 'PO3'};
for c = chans2plot
    plot(EEG.times, mean(EEG.data(find(strcmpi({EEG.chanlocs.labels},c)),:,:),3))
    hold on
end
legend(chans2plot)
title('ERP activity at 3 channels closest to simulated dipoles')

points2plot = 1:100:800;
for sp = 1:8
    tempdat = mean(mean(EEG.data(:,points2plot(sp):(points2plot(sp)+100),:),2),3);
    subplot(3,4,4+sp)
    topoplotIndie(tempdat, EEG.chanlocs);
    title([num2str(EEG.times(mean(points2plot(sp):(points2plot(sp)+100)))) 's']);
end

%% GED 

% initialize covariance matrices (chan_chan covariance matrix)
[covR,covS] = deal(zeros(EEG.nbchan));  % covR (reference); covS (signal)

% compute covariance matrices for each trial
for ti=1:EEG.trials
    % reference covariance matrix (before stimulus onset)
    tdat = squeeze(EEG.data(:,1:onset1idx,ti));
    covR = covR + cov(tdat');
    
    % signal covariance matrix (after stimulus onset)
    tdat = squeeze(EEG.data(:,onset1idx:end,ti));
    covS = covS + cov(tdat');
end

% average covariance
covR = covR./EEG.trials;
covS = covS./EEG.trials;

% perform GED
[evecs,evals] = eig(covS,covR);
[evals,sidx]  = sort(diag(evals),'descend'); % sort eigenvalues (largest to smallest)
evecs = evecs(:,sidx); % sort eigenvectors

%% compute filter forward models and flip sign
% component 1:
maps(:,1) = evecs(:,1)'*covS; % get component
[~,idx] = max(abs(maps(:,1)));  % find max magnitude
maps(:,1) = maps(:,1)*sign(maps(idx,1)); % possible sign fliip

% component 2:
maps(:,2) = evecs(:,2)'*covS; % get component
[~,idx] = max(abs(maps(:,2)));  % find max magnitude
maps(:,2) = maps(:,2)*sign(maps(idx,2)); % possible sign fliip

%% compute component time series (projections) (component "ERPs")
cdat = evecs(:,1:2)'*reshape(EEG.data,EEG.nbchan,[]);
cdat = reshape( cdat, [ 2 EEG.pnts EEG.trials ]);

%% plot component time series

figure(4); clf
for sp=1:2
    subplot(4,3,0+sp)
    plot(EEG.times, mean(cdat(sp,:,:),3));
    title([ 'Component ' num2str(sp) ' time series ("ERP")'])
end

%% show topographical maps and eigenspectrum 

for sp=1:2
    subplot(4,3,3+sp)
    topoplotIndie(maps(:,sp),EEG.chanlocs,'electrodes','labels');
    title([ 'Component ' num2str(sp) ])
end

subplot(436), plot(evals,'s-','linew',2,'markersize',10,'markerfacecolor','k')
set(gca,'xlim',[0 15])
ylabel('\lambda'), title('Eigenvalues of decomposition'), axis square

% components/eigenvectors can be correlated!

%% perform time-frequency analysis on components and two closest channels

% frequencies to extract (in Hz)
frex = linspace(2,20,20);

% convenient to have component time series data as 2D
% component time series
comp2d = reshape(cdat,2,[]); 
% channel time series
chans = {'PO3', 'Pz'};
eeg2d = reshape(EEG.data([find(strcmpi({EEG.chanlocs.labels},chans(1))) find(strcmpi({EEG.chanlocs.labels},chans(2)))],:,:),2,[]); 

% initialize time-frequency matrix
comptf = zeros(2,length(frex),EEG.pnts);
eegtf = comptf;

% loop over frequencies
for fi=1:length(frex)
    filtdatcomp = filterFGx(comp2d,EEG.srate,frex(fi),4);  % apply Gaussian bandpass filter
    filtdateeg = filterFGx(eeg2d,EEG.srate,frex(fi),4);  % apply Gaussian bandpass filter
    % loop over components
    for compi=1:2
        % apply Hilbert transform to compute power 
        as_comp = reshape(hilbert(filtdatcomp(compi,:)) ,EEG.pnts,EEG.trials);
        as_eeg = reshape(hilbert(filtdateeg(compi,:)) ,EEG.pnts,EEG.trials);
        % compute mean power
        comptf(compi,fi,:) = mean( abs(as_comp).^2 ,2);
        eegtf(compi,fi,:) = mean( abs(as_eeg).^2 ,2);
    end
end

%% plot time-frequency results

figure(4)
% plot component time-freq
for compi=1:2    
    subplot(4,3,6+compi)
    contourf(EEG.times,frex,squeeze(comptf(compi,:,:)),40,'linecolor','none')
    axis square
    title([ 'Component ' num2str(compi) ])
    xlabel('Time (s)'), ylabel('Frequency (Hz)')
end

% plot channel time-freq
for chani=1:2    
    subplot(4,3,9+chani)
    contourf(EEG.times,frex,squeeze(eegtf(compi,:,:)),40,'linecolor','none')
    axis square
    title([ 'Channel ' chans{chani} ])
    xlabel('Time (s)'), ylabel('Frequency (Hz)')
end

%% end
