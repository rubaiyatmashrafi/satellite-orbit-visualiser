% SatelliteOrbitVisualizer.m

% DESCRIPTION:
%   Animates a satellite performing a Hohmann or bi-elliptic orbital
%   transfer in 3D. Displays Earth, initial orbit, transfer arcs, final
%   orbit, and a live numeric overlay with delta-V and timing metrics.

% USAGE:
%   Run directly:
%       >> SatelliteOrbitVisualizer

% REQUIREMENTS:
%   Base MATLAB only (no toolboxes).
%   Optional: place "earth_texture.jpg" (equirectangular) in the same
%   folder for a textured Earth sphere; falls back to solid blue.

% PRESETS (selectable from GUI):
%   LEO -> GTO  : h1=400  km, h2=35786 km
%   LEO -> GEO  : h1=400  km, h2=35786 km  (same destination, circularised)
%   LEO -> MEO  : h1=400  km, h2=20200 km  (GPS-like orbit)

% MATH REFERENCE  (two-body, coplanar, impulsive burns, SI-km):
%   Constants:  mu = 398600.4418 km^3/s^2,  Re = 6378.137 km
%   vc(r)     = sqrt(mu/r)                    circular speed
%   at        = (r1+r2)/2                     Hohmann transfer SMA
%   vt_p      = sqrt(mu*(2/r1 - 1/at))        speed at perigee of transfer
%   vt_a      = sqrt(mu*(2/r2 - 1/at))        speed at apogee  of transfer
%   dV1       = vt_p - vc1                    1st burn delta-V
%   dV2       = vc2  - vt_a                   2nd burn delta-V
%   tt        = pi*sqrt(at^3/mu)              transfer time (half-period)
%   epsilon   = -mu/(2*a)                     specific orbital energy

function SatelliteOrbitVisualizer()

    %% Physical constants 
    mu = 398600.4418;   % Earth gravitational parameter [km^3/s^2]
    Re = 6378.137;      % Earth equatorial radius       [km]

    %% Default mission parameters 
    h1     = 400;       % Initial orbit altitude [km]  (LEO)
    h2     = 35786;     % Final orbit altitude   [km]  (GEO)
    rb_fac = 2.0;       % Bi-elliptic: intermediate radius = rb_fac * r2

    %% Colour theme 
    C.bgFig    = [0.03 0.04 0.08];
    C.bgAxes   = [0.01 0.02 0.05];
    C.bgPanel  = [0.06 0.08 0.14];
    C.bgPanel2 = [0.08 0.10 0.18];
    C.edge     = [0.25 0.40 0.75];
    C.text     = [0.88 0.93 1.00];
    C.label    = [0.68 0.82 1.00];
    C.value    = [1.00 0.95 0.65];
    C.button   = [0.12 0.24 0.45];
    C.button2  = [0.10 0.35 0.70];
    C.button3  = [0.18 0.18 0.28];
    C.statusOK  = [0.70 0.92 1.00];
    C.statusRun = [1.00 0.90 0.45];

    % Line colours used for orbit plots
    COL_ORBIT1    = [0.35 0.75 1.00];   % cyan-blue  : initial orbit
    COL_ORBIT2    = [0.25 0.90 0.45];   % green      : final orbit
    COL_TRANSFER  = [1.00 0.65 0.10];   % orange     : 1st transfer arc
    COL_TRANSFER2 = [1.00 0.30 0.60];   % pink-red   : 2nd arc (bi-elliptic)

    %% Build figure 
    fig = figure( ...
        'Name','Satellite Orbit & Transfer Visualizer', ...
        'NumberTitle','off', ...
        'Color',C.bgFig, ...
        'Position',[60 40 1380 820], ...
        'MenuBar','none', ...
        'ToolBar','figure', ...
        'Renderer','opengl', ...
        'CloseRequestFcn',@onClose);

    %% 3-D axes 
    ax = axes('Parent',fig, ...
        'Units','normalized', ...
        'Position',[0.02 0.05 0.60 0.90], ...
        'Color',C.bgAxes, ...
        'XColor',[0.45 0.55 0.75], ...
        'YColor',[0.45 0.55 0.75], ...
        'ZColor',[0.45 0.55 0.75], ...
        'GridColor',[0.25 0.30 0.45], ...
        'GridAlpha',0.18, ...
        'MinorGridAlpha',0.08, ...
        'DataAspectRatio',[1 1 1], ...
        'FontSize',10);
    hold(ax,'on');
    axis(ax,'equal');
    grid(ax,'on');
    box(ax,'on');
    xlabel(ax,'X (km)','Color',C.label);
    ylabel(ax,'Y (km)','Color',C.label);
    zlabel(ax,'Z (km)','Color',C.label);
    view(ax,30,25);
    title(ax,'3D Orbit Transfer Visualization', ...
        'Color',C.text,'FontWeight','bold','FontSize',14);

    %% Starfield 
    rng(2);
    nStars = 1000;
    starScale = 1.8e5;
    scatter3(ax, ...
        starScale*(rand(nStars,1)-0.5), ...
        starScale*(rand(nStars,1)-0.5), ...
        starScale*(rand(nStars,1)-0.5), ...
        2, [1 1 1], 'filled', ...
        'MarkerFaceAlpha',0.55, ...
        'MarkerEdgeAlpha',0.55);

    %% Earth sphere
    [sx,sy,sz] = sphere(96);
    sx = sx*Re; sy = sy*Re; sz = sz*Re;
    texFile = 'earth_texture.jpg';
    if exist(texFile,'file')
        cdata = imread(texFile);
        surf(ax,sx,sy,sz, ...
            'CData',flipud(cdata), ...
            'FaceColor','texturemap', ...
            'EdgeColor','none', ...
            'FaceLighting','gouraud', ...
            'SpecularStrength',0.22, ...
            'AmbientStrength',0.45, ...
            'DiffuseStrength',0.75);
    else
        surf(ax,sx,sy,sz, ...
            'FaceColor',[0.15 0.35 0.65], ...
            'EdgeColor','none', ...
            'FaceLighting','gouraud', ...
            'SpecularStrength',0.22, ...
            'AmbientStrength',0.45, ...
            'DiffuseStrength',0.75);
    end
    light(ax,'Position',[ 2  1  3]*1e5,'Style','infinite','Color',[1.00 0.98 0.90]);
    light(ax,'Position',[-1 -2 -2]*1e5,'Style','infinite','Color',[0.07 0.08 0.15]);

    gh.orbit1 = plot3(ax,NaN,NaN,NaN, ...
        'Color',COL_ORBIT1,'LineWidth',1.8,'LineStyle','-');

    gh.orbit2 = plot3(ax,NaN,NaN,NaN, ...
        'Color',COL_ORBIT2,'LineWidth',1.8,'LineStyle','-');

    gh.transfer = plot3(ax,NaN,NaN,NaN, ...
        'Color',COL_TRANSFER,'LineWidth',2.3,'LineStyle','--');

    gh.transfer2 = plot3(ax,NaN,NaN,NaN, ...
        'Color',COL_TRANSFER2,'LineWidth',1.8,'LineStyle','--');

    gh.sat = plot3(ax,NaN,NaN,NaN,'o', ...
        'MarkerSize',9, ...
        'MarkerFaceColor',[1 0.88 0.20], ...
        'MarkerEdgeColor','w', ...
        'LineWidth',1.2);

    gh.burnMark1 = plot3(ax,NaN,NaN,NaN,'s', ...
        'MarkerSize',9,'MarkerFaceColor',[1 0.35 0.10],'MarkerEdgeColor','w');

    gh.burnMark2 = plot3(ax,NaN,NaN,NaN,'s', ...
        'MarkerSize',9,'MarkerFaceColor',[1 0.35 0.10],'MarkerEdgeColor','w');

    gh.burnMark3 = plot3(ax,NaN,NaN,NaN,'s', ...
        'MarkerSize',9,'MarkerFaceColor',[1 0.10 0.65],'MarkerEdgeColor','w');

    gh.leg = legend(ax, ...
        [gh.orbit1, gh.transfer, gh.transfer2, gh.orbit2], ...
        {'Initial orbit (r_1)', ...
         'Transfer arc 1', ...
         'Transfer arc 2 (bi-elliptic)', ...
         'Final orbit (r_2)'}, ...
        'TextColor', C.text, ...
        'Color',     C.bgPanel, ...
        'EdgeColor', C.edge, ...
        'Location',  'southwest', ...
        'FontSize',  9);

    %% Right-side panel layout
    rightX = 0.64;
    rightW = 0.34;

    uicontrol('Parent',fig,'Style','text', ...
        'Units','normalized','Position',[rightX 0.94 rightW 0.04], ...
        'String','Satellite Orbit & Transfer Visualizer', ...
        'BackgroundColor',C.bgFig,'ForegroundColor',C.text, ...
        'FontSize',14,'FontWeight','bold','HorizontalAlignment','left');

    gh.overlayPanel = uipanel('Parent',fig, ...
        'Units','normalized','Position',[rightX 0.53 rightW 0.39], ...
        'BackgroundColor',C.bgPanel, ...
        'BorderType','line','ForegroundColor',C.edge, ...
        'HighlightColor',C.edge,'ShadowColor',[0 0 0], ...
        'Title','  Mission Metrics  ','FontSize',11,'FontWeight','bold');

    gh.overlayText = uicontrol('Parent',gh.overlayPanel, ...
        'Style','text', ...
        'Units','normalized','Position',[0.04 0.08 0.93 0.88], ...
        'BackgroundColor',C.bgPanel,'ForegroundColor',C.text, ...
        'FontName','Consolas','FontSize',11, ...
        'HorizontalAlignment','left','String','');

    gh.statusPanel = uipanel('Parent',fig, ...
        'Units','normalized','Position',[rightX 0.47 rightW 0.05], ...
        'BackgroundColor',C.bgPanel2, ...
        'BorderType','line','ForegroundColor',C.edge,'Title','','HighlightColor',C.edge);

    gh.statusText = uicontrol('Parent',gh.statusPanel, ...
        'Style','text', ...
        'Units','normalized','Position',[0.02 0.10 0.96 0.80], ...
        'BackgroundColor',C.bgPanel2,'ForegroundColor',C.statusOK, ...
        'FontSize',10,'FontWeight','bold', ...
        'HorizontalAlignment','left','String','Status: Ready');

    cpanel = uipanel('Parent',fig, ...
        'Units','normalized','Position',[rightX 0.04 rightW 0.41], ...
        'BackgroundColor',C.bgPanel, ...
        'BorderType','line','ForegroundColor',C.edge,'HighlightColor',C.edge, ...
        'Title','  Controls  ','FontSize',11,'FontWeight','bold');

    %% Slider helper function 
    bgCol = C.bgPanel;
    lbCol = C.label;

    function [sl,vlbl] = addSlider(yNorm, labelStr, vmin, vmax, vdef, fmt)
        uicontrol('Parent',cpanel,'Style','text', ...
            'Units','normalized','Position',[0.04 yNorm+0.045 0.52 0.05], ...
            'String',labelStr,'BackgroundColor',bgCol,'ForegroundColor',lbCol, ...
            'FontSize',10,'HorizontalAlignment','left');
        sl = uicontrol('Parent',cpanel,'Style','slider', ...
            'Units','normalized','Position',[0.04 yNorm 0.66 0.05], ...
            'Min',vmin,'Max',vmax,'Value',vdef, ...
            'BackgroundColor',[0.15 0.18 0.26], ...
            'SliderStep',[max(0.0005,1/(vmax-vmin)) max(0.005,10/(vmax-vmin))]);
        vlbl = uicontrol('Parent',cpanel,'Style','text', ...
            'Units','normalized','Position',[0.73 yNorm 0.23 0.05], ...
            'String',sprintf(fmt,vdef), ...
            'BackgroundColor',bgCol,'ForegroundColor',C.value, ...
            'FontSize',10,'FontWeight','bold','HorizontalAlignment','right');
    end

    [slH1,lblH1] = addSlider(0.80,'h1  Initial altitude (km)', 200,  2000,  h1,    '%.0f');
    [slH2,lblH2] = addSlider(0.63,'h2  Final altitude (km)',   500,  42164, h2,    '%.0f');
    [slRb,lblRb] = addSlider(0.46,'rb factor (bi-elliptic)',   1.05, 3.0,   rb_fac,'%.2f');
    set(slRb,'SliderStep',[0.01/1.95, 0.10/1.95]);

    uicontrol('Parent',cpanel,'Style','text', ...
        'Units','normalized','Position',[0.04 0.37 0.28 0.06], ...
        'String','Transfer mode','BackgroundColor',bgCol,'ForegroundColor',lbCol, ...
        'FontSize',10,'HorizontalAlignment','left');

    modePopup = uicontrol('Parent',cpanel,'Style','popupmenu', ...
        'Units','normalized','Position',[0.36 0.375 0.60 0.06], ...
        'String',{'Hohmann','BiElliptic'},'Value',1, ...
        'BackgroundColor',[0.10 0.12 0.20],'ForegroundColor',[1 1 0.7],'FontSize',10);

    % Camera preset buttons
    uicontrol('Parent',cpanel,'Style','pushbutton', ...
        'Units','normalized','Position',[0.04 0.29 0.29 0.06], ...
        'String','Isometric','BackgroundColor',C.button3,'ForegroundColor',C.text, ...
        'FontSize',9,'Callback',@(~,~) view(ax,30,25));

    uicontrol('Parent',cpanel,'Style','pushbutton', ...
        'Units','normalized','Position',[0.355 0.29 0.29 0.06], ...
        'String','Top View','BackgroundColor',C.button3,'ForegroundColor',C.text, ...
        'FontSize',9,'Callback',@(~,~) view(ax,0,90));

    uicontrol('Parent',cpanel,'Style','pushbutton', ...
        'Units','normalized','Position',[0.67 0.29 0.29 0.06], ...
        'String','Side View','BackgroundColor',C.button3,'ForegroundColor',C.text, ...
        'FontSize',9,'Callback',@(~,~) view(ax,90,0));

    uicontrol('Parent',cpanel,'Style','text', ...
        'Units','normalized','Position',[0.04 0.22 0.25 0.05], ...
        'String','Presets','BackgroundColor',bgCol,'ForegroundColor',lbCol, ...
        'FontSize',10,'HorizontalAlignment','left');

    presetNames = {'LEO -> GTO','LEO -> GEO','LEO -> MEO'};
    presetVals  = [400 35786; 400 35786; 400 20200];
    xPreset = [0.04 0.355 0.67];
    for i = 1:3
        uicontrol('Parent',cpanel,'Style','pushbutton', ...
            'Units','normalized','Position',[xPreset(i) 0.14 0.29 0.07], ...
            'String',presetNames{i}, ...
            'BackgroundColor',C.button,'ForegroundColor',C.text, ...
            'FontSize',9,'FontWeight','bold', ...
            'Callback',@(~,~) applyPreset(presetVals(i,1), presetVals(i,2)));
    end

    uicontrol('Parent',cpanel,'Style','pushbutton', ...
        'Units','normalized','Position',[0.04 0.03 0.92 0.085], ...
        'String','Animate Transfer', ...
        'FontSize',12,'FontWeight','bold', ...
        'BackgroundColor',C.button2,'ForegroundColor','white', ...
        'Callback',@onAnimate);

    %%Slider live-update callbacks
    set(slH1,'Callback',@(s,~) onSlide(s,lblH1,'%.0f'));
    set(slH2,'Callback',@(s,~) onSlide(s,lblH2,'%.0f'));
    set(slRb,'Callback',@(s,~) onSlide(s,lblRb,'%.2f'));
    set(modePopup,'Callback',@(~,~) refreshScene());

    refreshScene();

    function refreshScene()
        [h1_,h2_,mode_,rb_] = readUI();
        data = computeOrbits(h1_,h2_,mu,Re,mode_,rb_);
        drawOrbits(data);
        updateOverlay(data);
        setStatus('Ready','ok');
    end

    function onAnimate(~,~)
    % Animate button callback.
        [h1_,h2_,mode_,rb_] = readUI();
        data = computeOrbits(h1_,h2_,mu,Re,mode_,rb_);
        drawOrbits(data);
        updateOverlay(data);
        setStatus('Animating transfer...','run');
        animateTransfer(data);
        setStatus('Animation complete','ok');
    end

    function applyPreset(pH1,pH2)
        set(slH1,'Value',pH1); set(lblH1,'String',sprintf('%.0f',pH1));
        set(slH2,'Value',pH2); set(lblH2,'String',sprintf('%.0f',pH2));
        refreshScene();
    end

    function [h1_,h2_,mode_,rb_fac_] = readUI()
        h1_     = get(slH1,'Value');
        h2_     = get(slH2,'Value');
        rb_fac_ = get(slRb,'Value');
        modes   = {'Hohmann','BiElliptic'};
        mode_   = modes{get(modePopup,'Value')};
    end

    function onSlide(sl_,lbl_,fmt)
        set(lbl_,'String',sprintf(fmt,get(sl_,'Value')));
        refreshScene();
    end

    function setStatus(msg,kind)
        if strcmp(kind,'run')
            set(gh.statusText,'ForegroundColor',C.statusRun);
        else
            set(gh.statusText,'ForegroundColor',C.statusOK);
        end
        set(gh.statusText,'String',['Status: ' msg]);
        drawnow limitrate;
    end

    function onClose(~,~)
        delete(fig);
    end

    %  ORBIT COMPUTATION

    function data = computeOrbits(h1_,h2_,mu_,Re_,mode_,rb_fac_)
    % Computes all orbital parameters and pre-builds trajectory arrays.
    %
    % Everything is in the equatorial plane (Z = 0).
    % The transfer ellipse is oriented with periapsis on the +X axis:
    %   nu = 0   -> satellite at r_perigee  (positive X)
    %   nu = pi  -> satellite at r_apogee   (negative X)

        r1  = Re_ + h1_;
        r2  = Re_ + h2_;
        vc1 = sqrt(mu_/r1);   % circular speed at r1 [km/s]
        vc2 = sqrt(mu_/r2);   % circular speed at r2 [km/s]

        data.r1   = r1;   data.r2   = r2;
        data.h1   = h1_;  data.h2   = h2_;
        data.vc1  = vc1;  data.vc2  = vc2;
        data.mode = mode_;
        data.mu   = mu_;

        if strcmp(mode_,'Hohmann')
            at  = (r1 + r2)/2;               % transfer ellipse semi-major axis
            vtp = sqrt(mu_*(2/r1 - 1/at));   % speed at perigee of transfer (= r1)
            vta = sqrt(mu_*(2/r2 - 1/at));   % speed at apogee  of transfer (= r2)

            dV1 = vtp - vc1;   % 1st burn: speed up at r1 to enter transfer orbit
            dV2 = vc2 - vta;   % 2nd burn: speed up at r2 to circularise

            % Half-period of the transfer ellipse = transfer time
            tt = pi * sqrt(at^3 / mu_);

            data.at       = at;
            data.dV1      = dV1;
            data.dV2      = dV2;
            data.dV3      = NaN;
            data.dVtotal  = abs(dV1) + abs(dV2);
            data.tt       = tt;
            data.epsilon1 = -mu_/(2*r1);   % specific orbital energy [km^2/s^2]
            data.epsilon2 = -mu_/(2*r2);
            data.epsilonT = -mu_/(2*at);

            % Geometry
            theta = linspace(0, 2*pi, 360);
            data.orbit1XYZ    = circOrbitXYZ(r1, theta);
            data.orbit2XYZ    = circOrbitXYZ(r2, theta);
            % Transfer arc from perigee (nu=0, +X) to apogee (nu=pi, -X)
            data.transferXYZ  = ellipseArcXYZ(r1, r2, at, linspace(0, pi, 220));
            data.transfer2XYZ = [];   % not used for Hohmann

            % Burn markers: square symbols placed at each dV point
            data.burnPt1 = data.transferXYZ(:,1)';    % perigee (+X side)
            data.burnPt2 = data.transferXYZ(:,end)';  % apogee  (-X side)
            data.burnPt3 = [NaN NaN NaN];

            nLeadIn   = 55;   % ~quarter arc on orbit 1
            nFinalArc = 80;   % half arc on orbit 2
            p1 = circOrbitXYZ(r1, linspace(-pi/2, 0, nLeadIn));
            p2 = data.transferXYZ;
            p3 = circOrbitXYZ(r2, linspace(0, pi, nFinalArc));
            data.animPath = [p1, p2, p3]';   % Nx3

        else  % BiElliptic
            rb  = rb_fac_ * r2;    % intermediate apogee radius

            at1 = (r1 + rb) / 2;  % SMA of 1st transfer ellipse
            at2 = (rb + r2) / 2;  % SMA of 2nd transfer ellipse

            % Speeds at the three burn points
            vt1p = sqrt(mu_*(2/r1 - 1/at1));  % perigee of ellipse 1  (at r1)
            vt1a = sqrt(mu_*(2/rb - 1/at1));   % apogee  of ellipse 1  (at rb)
            vt2a = sqrt(mu_*(2/rb - 1/at2));   % apogee  of ellipse 2  (at rb)
            vt2p = sqrt(mu_*(2/r2 - 1/at2));   % perigee of ellipse 2  (at r2)

            dV1 = vt1p - vc1;   % depart r1
            dV2 = vt2a - vt1a;  % kick at intermediate apogee rb
            dV3 = vc2  - vt2p;  % circularise at r2

            tt1 = pi * sqrt(at1^3 / mu_);
            tt2 = pi * sqrt(at2^3 / mu_);

            data.at       = at1;
            data.at2      = at2;
            data.rb       = rb;
            data.dV1      = dV1;
            data.dV2      = dV2;
            data.dV3      = dV3;
            data.dVtotal  = abs(dV1) + abs(dV2) + abs(dV3);
            data.tt       = tt1 + tt2;
            data.epsilon1 = -mu_/(2*r1);
            data.epsilon2 = -mu_/(2*r2);
            data.epsilonT = -mu_/(2*at1);

            % Geometry
            theta = linspace(0, 2*pi, 360);
            data.orbit1XYZ = circOrbitXYZ(r1, theta);
            data.orbit2XYZ = circOrbitXYZ(r2, theta);

            % 1st arc: r1 (perigee, nu=0) -> rb (apogee, nu=pi)
            data.transferXYZ = ellipseArcXYZ(r1, rb, at1, linspace(0, pi, 220));


            data.transfer2XYZ = ellipseArcXYZ(r2, rb, at2, linspace(pi, 2*pi, 220));

            % Burn markers
            data.burnPt1 = data.transferXYZ(:,1)';     % r1,  nu=0      (1st burn)
            data.burnPt2 = data.transferXYZ(:,end)';   % rb,  nu=pi     (2nd burn)
            data.burnPt3 = data.transfer2XYZ(:,end)';  % r2,  nu=2*pi   (3rd burn)

            % FIX 1 (bi-elliptic): same short lead-in approach
            nLeadIn   = 55;
            nFinalArc = 80;
            p1 = circOrbitXYZ(r1, linspace(-pi/2, 0, nLeadIn));
            p2 = data.transferXYZ;
            p3 = data.transfer2XYZ;
            % Final orbit arc: starts where 2nd transfer ends.
            % At nu=2*pi the satellite is back at +X (same as nu=0),
            % so orbit 2 lead-out goes from 0 to pi (upper half).
            p4 = circOrbitXYZ(r2, linspace(0, pi, nFinalArc));
            data.animPath = [p1, p2, p3, p4]';
        end

        % Hohmann equivalent dV always stored for comparison panel
        at_h  = (r1 + r2) / 2;
        vtp_h = sqrt(mu_*(2/r1 - 1/at_h));
        vta_h = sqrt(mu_*(2/r2 - 1/at_h));
        data.hohmann_dV = abs(vtp_h - vc1) + abs(vc2 - vta_h);
    end

    %  TRAJECTORY HELPERS

    function xyz = circOrbitXYZ(r, theta)
    % 3xN array of points on a circular orbit of radius r in the XY plane.
        xyz = [r*cos(theta); r*sin(theta); zeros(size(theta))];
    end

    function xyz = ellipseArcXYZ(rp, ra, a, nu_vec)
    % 3xN array for a Keplerian ellipse arc parameterised by true anomaly.
    %
    %   rp     – periapsis radius [km]  (must be < ra)
    %   ra     – apoapsis  radius [km]
    %   a      – semi-major axis  [km]
    %   nu_vec – array of true anomaly values [rad]
    %
    % The periapsis is on the +X axis (nu=0 -> point (rp, 0, 0)).
    % Eccentricity e = (ra-rp)/(ra+rp) > 0 guaranteed when ra > rp.
        e   = (ra - rp) / (ra + rp);
        p   = a * (1 - e^2);                    % semi-latus rectum
        r   = p ./ (1 + e*cos(nu_vec));          % orbit equation
        xyz = [r.*cos(nu_vec); r.*sin(nu_vec); zeros(size(nu_vec))];
    end

    %  DRAWING

    function drawOrbits(data)
    % Updates all line-handle XYZ data and repositions burn markers.
        set(gh.orbit1, ...
            'XData',data.orbit1XYZ(1,:), ...
            'YData',data.orbit1XYZ(2,:), ...
            'ZData',data.orbit1XYZ(3,:));

        set(gh.orbit2, ...
            'XData',data.orbit2XYZ(1,:), ...
            'YData',data.orbit2XYZ(2,:), ...
            'ZData',data.orbit2XYZ(3,:));

        set(gh.transfer, ...
            'XData',data.transferXYZ(1,:), ...
            'YData',data.transferXYZ(2,:), ...
            'ZData',data.transferXYZ(3,:));

        if ~isempty(data.transfer2XYZ)
            set(gh.transfer2, ...
                'XData',data.transfer2XYZ(1,:), ...
                'YData',data.transfer2XYZ(2,:), ...
                'ZData',data.transfer2XYZ(3,:));
        else
            set(gh.transfer2,'XData',NaN,'YData',NaN,'ZData',NaN);
        end

        % Burn-point square markers
        set(gh.burnMark1, ...
            'XData',data.burnPt1(1), ...
            'YData',data.burnPt1(2), ...
            'ZData',data.burnPt1(3));
        set(gh.burnMark2, ...
            'XData',data.burnPt2(1), ...
            'YData',data.burnPt2(2), ...
            'ZData',data.burnPt2(3));
        if ~any(isnan(data.burnPt3))
            set(gh.burnMark3, ...
                'XData',data.burnPt3(1), ...
                'YData',data.burnPt3(2), ...
                'ZData',data.burnPt3(3));
        else
            set(gh.burnMark3,'XData',NaN,'YData',NaN,'ZData',NaN);
        end

        % Place satellite at start of animation path
        set(gh.sat, ...
            'XData',data.animPath(1,1), ...
            'YData',data.animPath(1,2), ...
            'ZData',data.animPath(1,3));

        % Auto-scale axes to frame all orbits with a small margin
        allPts = [data.orbit1XYZ, data.orbit2XYZ, data.transferXYZ];
        if ~isempty(data.transfer2XYZ)
            allPts = [allPts, data.transfer2XYZ];
        end
        maxR = 1.12 * max(abs(allPts(:)));
        axis(ax, [-maxR maxR -maxR maxR -maxR maxR]);

        drawnow limitrate;
    end

    %  MISSION METRICS OVERLAY

    function updateOverlay(data)
        tt_hr = data.tt / 3600;

        if strcmp(data.mode,'Hohmann')
            lines = {
                sprintf('Mode         : Hohmann transfer')
                ' '
                sprintf('h1           : %10.0f  km',     data.h1)
                sprintf('h2           : %10.0f  km',     data.h2)
                ' '
                sprintf('r1           : %10.3f  km',     data.r1)
                sprintf('r2           : %10.3f  km',     data.r2)
                ' '
                sprintf('vc1          : %10.4f  km/s',   data.vc1)
                sprintf('vc2          : %10.4f  km/s',   data.vc2)
                ' '
                sprintf('Delta-V1     : %+10.4f km/s',   data.dV1)
                sprintf('Delta-V2     : %+10.4f km/s',   data.dV2)
                sprintf('Delta-V total: %10.4f  km/s',   data.dVtotal)
                ' '
                sprintf('Transfer time: %10.3f  hr',     tt_hr)
                ' '
                sprintf('eps_1        : %10.3f  km2/s2', data.epsilon1)
                sprintf('eps_2        : %10.3f  km2/s2', data.epsilon2)
                sprintf('eps_T        : %10.3f  km2/s2', data.epsilonT)
            };
        else
            saving = data.hohmann_dV - data.dVtotal;
            lines = {
                sprintf('Mode         : Bi-elliptic transfer')
                ' '
                sprintf('h1           : %10.0f  km',     data.h1)
                sprintf('h2           : %10.0f  km',     data.h2)
                sprintf('rb           : %10.0f  km',     data.rb)
                ' '
                sprintf('vc1          : %10.4f  km/s',   data.vc1)
                sprintf('vc2          : %10.4f  km/s',   data.vc2)
                ' '
                sprintf('Delta-V1     : %+10.4f km/s',   data.dV1)
                sprintf('Delta-V2     : %+10.4f km/s',   data.dV2)
                sprintf('Delta-V3     : %+10.4f km/s',   data.dV3)
                sprintf('Delta-V total: %10.4f  km/s',   data.dVtotal)
                ' '
                sprintf('Transfer time: %10.3f  hr',     tt_hr)
                ' '
                sprintf('Hohmann dV   : %10.4f  km/s',   data.hohmann_dV)
                sprintf('Saving vs H  : %+10.4f km/s',   saving)
            };
        end

        set(gh.overlayText,'String',lines);
    end

    %  ANIMATION

    function animateTransfer(data)
    % Steps the satellite marker along the pre-computed animation path.
    % Frame delay is chosen so the total animation takes ~12-15 seconds
    % regardless of path length, capped between 10 ms and 50 ms per frame.
        path    = data.animPath;   % Nx3
        N       = size(path,1);
        frameDt = min(0.050, max(0.010, 12/N));

        for k = 1:N
            if ~isvalid(fig), return; end   % abort cleanly if window is closed
            set(gh.sat, ...
                'XData',path(k,1), ...
                'YData',path(k,2), ...
                'ZData',path(k,3));
            drawnow limitrate;
            pause(frameDt);
        end
    end

end  % end SatelliteOrbitVisualizer
