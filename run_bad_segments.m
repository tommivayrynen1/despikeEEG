
function [data,cfig] = run_bad_segments(data)

    cfig= figure('Position',[3632         386         202         610]);
    %btn = uibutton(cfig,'Position',[50 500 125 40],'Text','RE-CALCULATE','ButtonPushedFcn',@(btn,event) RECalc(btn));
    btn = uicontrol('Parent', cfig, 'Style', 'pushbutton','Position',[50 500 125 40],'String','RE-CALCULATE','Callback',{@RECalc,data});
    btn2 = uicontrol('Parent', cfig, 'Style', 'pushbutton','Position',[50 100 125 40],'String','Done','Callback',@ExitFun);
    edt1 = uicontrol('Parent', cfig, 'Style', 'edit','Position',[50 450 125 40],'String', 4.5);
    edt2 = uicontrol('Parent', cfig, 'Style', 'edit','Position',[50 400 125 40],'String', 10000);
    edt3 = uicontrol('Parent', cfig, 'Style', 'edit','Position',[50 350 125 40],'String', 750);
    edt4 = uicontrol('Parent', cfig, 'Style', 'edit','Position',[50 300 125 40],'String', 10);
    edt5 = uicontrol('Parent', cfig, 'Style', 'edit','Position',[50 250 125 40],'String', 10);
    edt6 = uicontrol('Parent', cfig, 'Style', 'edit','Position',[50 200 125 40],'String', 1000);


    lbl = uicontrol('Parent', cfig,'Style','text','Position',[70 480 125 15],'String','Z-score th');
    lbl = uicontrol('Parent', cfig,'Style','text','Position',[70 430 125 15],'String','Kurtosis th');
    lbl = uicontrol('Parent', cfig,'Style','text','Position',[70 380 125 15],'String','Z-res th (separating res)');
    lbl = uicontrol('Parent', cfig,'Style','text','Position',[70 330 125 15],'String','Num of win');
    lbl = uicontrol('Parent', cfig,'Style','text','Position',[70 280 125 15],'String','Ratio for global bad');
    lbl = uicontrol('Parent', cfig,'Style','text','Position',[70 230 125 15],'String','Z-score bypass for global');

        function data=RECalc(src,event,data)
            initials = [str2num(edt1.String),str2num(edt2.String),str2num(edt3.String),str2num(edt4.String),str2num(edt5.String),str2num(edt6.String)]
            data = update_segments(initials,data)
        end

        function y=ExitFun(src,event)
            disp('Continuing..')
            %uiresume(cfig)
            close all
        end
    %uiwait(cfig)
end 
