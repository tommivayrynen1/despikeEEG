
function data=update_segments(initials,data)


raw=cell2mat(data.trial);
raw2=raw;       % apply ica weights to this
srate=data.fsample;
chanlist = find(~isnan(raw(:,1)));
chanlist(find(chanlist == 258)) = []; % ECG = 258, remove


% PREPARES DATA FOR ICA, CUTS OUT SPIKES FROM THE CHOSEN TIMEPOINTS, FROM
% ALL CHANNELS (SAME TIMEPOINTS!)

%% Define weight matrix & Thresholds

artificial = zeros(length(chanlist),size(raw,2));
zscore=zeros(length(chanlist),size(raw,2));


l = size(raw,2);
z_th = initials(1);                                   % z score threshold, /5                                                                                                       5
k_th = initials(2);                                   % kurtosis threhsold. NO CURTOSIS ATM
z_res = initials(3);                                  % separating resolution between articial segments (large value blends neighbouring artefacts to one) / 750
bufferlen = 0.3*srate;                                % length of buffer zones used in interpolation
ratio_for_global_bad = initials(5);                   % ratio when artefact is accepted to be removed                                                      /25
zscore_for_global_bad = initials(6);                  % this can bypass previous ratio and likewise (if sum of all channels szore is higher than this)    650
sep_th = 2*srate;
max_padding = 0.4*srate;                              % max 0.2 sec padding (0.4 * srate)
ut = 1500;
lt = -1500;                                           % control find reds initial values
numofwin= initials(4);




counter = 0;
if rem(size(raw,2),numofwin) ~= 0
   while 1 
       counter =counter+1;
        numofwin = numofwin + 1;
        if rem(size(raw,2),numofwin) ~= 0 && isinteger(l/numofwin) == 1
            break
         
%         elseif counter > 500000
%             numofwin=1;
%             break
        end
   end
end
winl = l/numofwin;
disp(sprintf('Using %i windows',numofwin))

%%

for t = 1:length(chanlist)  %sliding zscore, DONT TAKE EKG AND REF
s = raw(chanlist(t),:);
for i=1:numofwin
   switch i
       case 1
        from = 1;
        to = i*winl;
       otherwise   
        from = (i-1)*winl;
        to = i*winl;
   end
  zscore(t,from:to)=(s(from:to)-mean(s(from:to)))./std(s(from:to));
end
end


z_ind=abs(zscore)>z_th;     %Over thershold logical
kurt = zeros(length(chanlist),size(s,2));        % Kurtosis calculations


kurt_stored = zeros(length(chanlist),200);
wins = [180:1:220];n_win = rem(length(s),wins);n_win=find(n_win==0);n_win=wins(n_win(end));     % Number of windows to kurtosis calculation
winlen = length(s)/n_win;
for n = 1:length(chanlist)
    s = raw(chanlist(n),:);
    for i = 1:200
        if i == 1;
            from = 1;
            to = i*winlen;
        else
            from = (i-1)*winlen+1;
            to = i*winlen;
        end
        ikkuna = s(from:to);
        kurti = sum(((ikkuna-mean(ikkuna)).^4)/(length(ikkuna)*(std(ikkuna))^4));
        kurt_stored(n,i) = kurti;
        if kurti > k_th;     
           kurt(n,from:to) = linspace(1,1,winlen);
        else
           kurt(n,from:to) = zeros(1,winlen);
        end
    end
end

artificial = kurt + z_ind ; % logical matrix

artificial2=zeros(1,size(raw,2));
for n = 1 : length(raw)
    num_bad = sum(artificial(:,n));
    if num_bad > ratio_for_global_bad || sum(zscore(:,n)) > zscore_for_global_bad
        artificial2(1,n) = 1;
    else
        artificial2(1,n) = 0;
    end
end


s_e_array = [];
r = 1
ar_indices = find(artificial2);
s_e_array(r,1) = ar_indices(1);


for j = 1:length(ar_indices)-1      %generate array with start and ends times for artefacts with separation threshold
    if (abs(ar_indices(j)-ar_indices(j+1)) > sep_th) && j~=length(ar_indices)-1 % 
       s_e_array(r,2) = ar_indices(j);
       r = r+1;
       s_e_array(r,1) = ar_indices(j+1);
    elseif j == length(ar_indices)-1 && (abs(ar_indices(j)-ar_indices(j+1)) > sep_th)
       s_e_array(r,2) = ar_indices(j);
       r = r+1;
       s_e_array(r,1) = ar_indices(j+1);
       s_e_array(r,2) = ar_indices(j+1);
    elseif j == length(ar_indices)-1
       s_e_array(r,2) = ar_indices(j+1);
    end
end


s_e_array(:,1) = s_e_array(:,1)-bufferlen; % define buffer lengths
s_e_array(:,2) = s_e_array(:,2)+bufferlen;
li=find(s_e_array <= 0);
ui=find(s_e_array >= size(raw,2));
s_e_array(li)=1;
s_e_array(ui)=size(raw,2);


%% find best fit for padding (mean diff for all channels)

best_i=zeros(2,size(s_e_array,1));
for l = 1:size(s_e_array,1)
    differ = [];
    j = 0;
    while 1     % laita maksimi j:lle ja ehdot (etsi minimi jos alle limitin erotusta ei loydeta tietyllä valilla)
                        %for j = 1:0.5*srate %find minimized offset between edges (2*0.5*srate = max search area = 1s)
        j = j+1;
        if s_e_array(l,1) == 1 || s_e_array(l,1)-j <= 0 % Only if start is artefact
            start_x = 1;
        else
            start_x = s_e_array(l,1)-j;
        end
        corresp_y_s=raw(1:chanlist,start_x);
        if s_e_array(l,2) == length(raw)
            end_x = length(raw);
        else
            end_x =s_e_array(l,2)+j;
        end
        corresp_y_e=raw(1:chanlist,end_x);
        differ(j) = mean(abs(corresp_y_e-corresp_y_s));
        if differ(j) < 20 || j > max_padding || end_x + 1 >= length(raw)
            
            break;
        end
    end

    if length(differ) >= max_padding
        best_i(1,l) = find(differ == min(differ));
        best_i(2,l) = min(differ);
    else
        best_i(1,l) = find(differ == differ(end));
        best_i(2,l) = differ(end);
    end
    
end

s=s_e_array(:,1)-best_i(1,:)';
e=s_e_array(:,2)+best_i(1,:)';
s_e_array(:,1)=s_e_array(:,1)-best_i(1,:)';
s_e_array(:,2)=s_e_array(:,2)+best_i(1,:)';
s_e_array(find(s_e_array <= 1)) = 1;
s_e_array(find(s_e_array >= length(raw))) = length(raw);



if size(s_e_array,1)==1
    
    clear_seg = [1:s_e_array(1,1),s_e_array(1,2):length(raw)];
    cut_raw=raw(:,clear_seg); %ok   

else

    %first segment if exist doesnt start with artef
    cut_raw=[]
    if s_e_array(1,1) ~= 1
        cut_raw = raw(:,1:s_e_array(1,1));
    end
    % loop over 2:n-1 segments
    for l = 1:length(s_e_array)-1
        clear_seg = s_e_array(l,2):s_e_array(l+1,1);
        cut_raw(:,length(cut_raw)+1:length(cut_raw)+length(clear_seg))=raw(:,clear_seg); %ok   
    end
    % last segment if exist (artefact does not go all the way)
    if s_e_array(end,2) ~= size(raw,2)
        end_seg = s_e_array(end,2):size(raw,2);
        cut_raw(:,length(cut_raw)+1:length(cut_raw)+length(end_seg)) = raw(:,end_seg);    
    end
end

% MAKE SURE NO JUMP BETWEEN ARTEFACTS.
% ***************************************************************
%     for i=1:size(raw,1)
%         for l = 1:length(s_e_array)
%             med1=median(raw(i,s_e_array(l,1)-10*srate:s_e_array(l,1))); % before median
%             med2=median(raw(i,s_e_array(l,2):s_e_array(l,2)+10*srate)); % after median
%             offset = med2-med1;
%             cut_raw
%         end
%     end
%     cut_raw(:,)-offset


%      PLOTS
x_space = zeros(length(chanlist),200);
for i = 1:200
    x_space(:,i) = [1:1:length(chanlist)]';
end
zscore_dump=zscore;
zscore=zeros(size(raw,1),size(raw,2));zscore(chanlist,:)=zscore_dump;

%%
fig1=figure;
subplot(3,6,1:3);plot(abs(zscore(1,:)),'Color','k');hold on;plot([1 length(zscore)],[z_th z_th],'--','Color','r','LineWidth',2);hold on;title('Sliding zscore');ylim([0 50])
subplot(3,6,4:6);scatter(reshape(kurt_stored,[1,length(chanlist)*200]),reshape(x_space,[1,(length(chanlist))*200]),'filled');title('Kurtosis');hold on;plot([k_th k_th],[0 length(chanlist)],'--','Color','r','LineWidth',2);ylabel('Channel')
ylim([0 257])

subplot(3,6,7:12);plot(raw(1,:),'Color','k');hold on;
for i = 1:size(s_e_array,1)
    plot([s_e_array(i,1):1:s_e_array(i,2)],raw(1,s_e_array(i,1):s_e_array(i,2)),'Color','r');hold on;
end
lims=get(gca);lims=lims.YLim;

subplot(3,6,13:18);plot(cut_raw(1,:),'Color','k');ylim(lims)

scroll1 = uicontrol('Style','slider','Parent',fig1,'Units','normalized','Position',[0.15 0.02 0.7 0.025],'Value',1,'Min',1,'Max',size(raw,1),'SliderStep', [1/255 1/255]);
set(scroll1,'Callback',@scroll_prepare_ICA);

% WAIT FOR FIG 1 CLOSING
disp('CLOSE FIGURE TO CONTINUE')
waitfor(fig1)


function scroll_prepare_ICA(hObject,eventdata)
    %fig1 = evalin('base','fig1');
    allAxesInFigure = findall(fig1,'type','axes');
    cla(allAxesInFigure(1))
    cla(allAxesInFigure(2))
    cla(allAxesInFigure(4))

    slider_value = round(get(hObject,'Value'));
    disp(slider_value)
    k = slider_value

    % raw = evalin('base','raw');
    % cut_raw = evalin('base','cut_raw');
    % s_e_array = evalin('base','s_e_array');
    % zscore = evalin('base','zscore');
    % z_th = evalin('base','z_th');


    subplot(3,6,1:3);plot(abs(zscore(k,:)),'Color','k');hold on;plot([1 length(zscore)],[z_th z_th],'--','Color','r','LineWidth',2);hold on;title('Sliding zscore');ylim([0 50])

    subplot(3,6,7:12);plot(raw(k,:),'Color','k');hold on;
    for i = 1:size(s_e_array,1)
        plot([s_e_array(i,1):1:s_e_array(i,2)],raw(k,s_e_array(i,1):s_e_array(i,2)),'Color','r');hold on;
    end
    %;ylim([-1000 1000])
    lims=get(gca);lims=lims.YLim;
    xlim([1 size(raw,2)])
    subplot(3,6,13:18);plot(cut_raw(k,:),'Color','k');ylim(lims);xlim([1 size(raw,2)])
end


data.preprocessing.badsegs=s_e_array;
data.preprocessing.shortsig=cut_raw;
assignin('base','data',data)

end



