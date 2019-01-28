clear all;

    acadoSet('problemname', 'kugle_mpc_export'); 

    %% Define variables (both internal and external/inputs)
    DifferentialState q2; % OBS. The order of construction defines the order in the chi vector
    DifferentialState q3;
    DifferentialState x;
    DifferentialState y;
    DifferentialState dx;
    DifferentialState dy;   
    DifferentialState s;
    DifferentialState ds;
    DifferentialState omega_ref_x;
    DifferentialState omega_ref_y;
    
    Control domega_ref_x;
    Control domega_ref_y;   
    Control dds;
    Control velocity_slack_variable;
    %Control angle_slack_variable;
    %Control tube_left_slack_variable;
    %Control tube_right_slack_variable;
    Control proximity_slack_variable;
    
    ts = 1/10;   
    N = 30;      
    
    %OnlineData represents data that can be passed to the solver online (real-time)
    OnlineData desiredVelocity;
    OnlineData maxVelocity;    
    OnlineData maxAngle;
    OnlineData maxOmegaRef;        
    OnlineData trajectoryLength;
    OnlineData trajectoryStart;    
    
    % Reference polynomial coefficients (for up to 7th order polynomial)
    OnlineData cx9;
    OnlineData cx8;
    OnlineData cx7;
    OnlineData cx6;
    OnlineData cx5;
    OnlineData cx4;
    OnlineData cx3;
    OnlineData cx2;
    OnlineData cx1;
    OnlineData cx0;
    OnlineData cy9;
    OnlineData cy8;
    OnlineData cy7;
    OnlineData cy6;
    OnlineData cy5;
    OnlineData cy4;
    OnlineData cy3;
    OnlineData cy2;
    OnlineData cy1;
    OnlineData cy0;
    
%     OnlineData tubeLeft;
%     OnlineData tubeRight;
    

    OnlineData obs1_x;
    OnlineData obs1_y;
    OnlineData obs1_r;
    
    OnlineData obs2_x;
    OnlineData obs2_y;
    OnlineData obs2_r;
    
    OnlineData obs3_x;
    OnlineData obs3_y;
    OnlineData obs3_r;
    
    OnlineData obs4_x;
    OnlineData obs4_y;
    OnlineData obs4_r;
    
    OnlineData obs5_x;
    OnlineData obs5_y;
    OnlineData obs5_r;

    % Evaluate polynomial based on s variable
    % Intermediate states helps to speed up the Automatic Differentiation of ACADO Symbolic
    s_ = acado.IntermediateState(s + trajectoryStart);
    %x_ref = acado.IntermediateState(cx11*s_^11 + cx10*s_^10 + cx9*s_^9 + cx8*s_^8 + cx7*s_^7 + cx6*s_^6 + cx5*s_^5 + cx4*s_^4 + cx3*s_^3 + cx2*s_^2 + cx1*s_ + cx0);
    %y_ref = acado.IntermediateState(cy11*s_^11 + cy10*s_^10 + cy9*s_^9 + cy8*s_^8 + cy7*s_^7 + cy6*s_^6 + cy5*s_^5 + cy4*s_^4 + cy3*s_^3 + cy2*s_^2 + cy1*s_ + cy0);
    x_ref = acado.IntermediateState(cx9*s_^9 + cx8*s_^8 + cx7*s_^7 + cx6*s_^6 + cx5*s_^5 + cx4*s_^4 + cx3*s_^3 + cx2*s_^2 + cx1*s_ + cx0);
    y_ref = acado.IntermediateState(cy9*s_^9 + cy8*s_^8 + cy7*s_^7 + cy6*s_^6 + cy5*s_^5 + cy4*s_^4 + cy3*s_^3 + cy2*s_^2 + cy1*s_ + cy0);
    
    %TIME t; % the TIME
    %Parameter l; % parameters are time varying variables
    %Variable
    %Vector  (use BVector instead)
    %Matrix  (use BMatrix instead)
    %ExportVariable
        
    %input1 = acado.MexInput; % inputs into the MEX function in the order of construction
    %input2 = acado.MexInputVector; % myexample RUN(10, [0 1 2 3], eye(3,3)),
    %input3 = acado.MexInputMatrix;
    
    % Quaternion to Acceleration coefficient can either be hardcoded or taken as input through OnlineData (since I have not been able to find any other/better way?)
    QuaternionToAccelerationCoefficient = 13.71;
    %OnlineData QuaternionToAccelerationCoefficient;

    %% Define differential equation (model of plant) - (see page ?? in ACADO MATLAB manual)
    f = acado.DifferentialEquation();  
    % possibility 1: link a Matlab ODE
    % f.linkMatlabODE('LinearMPCmodel_acado'); % however this method will slow down the generated code
    % possibility 2: write down the ODE directly in ACADO syntax    
    f.add(dot(q2) == 1/2 * omega_ref_x);
    f.add(dot(q3) == 1/2 * omega_ref_y);
    f.add(dot(x) == dx);
    f.add(dot(y) == dy);
    f.add(dot(dx) == QuaternionToAccelerationCoefficient*q3);
    f.add(dot(dy) == -QuaternionToAccelerationCoefficient*q2);
    f.add(dot(s) == ds);  
    f.add(dot(ds) == dds);
    f.add(dot(omega_ref_x) == domega_ref_x);
    f.add(dot(omega_ref_y) == domega_ref_y);
    % possibility 4: write down the discretized ODE directly in ACADO syntax
    % Note that the start time, end time, step size (ts), and the number N of control intervals should be chosen in such a way that the relation
    % (t_end - t_start) / ts = N*i    (should hold for some integer, i)
    % f = acado.DiscretizedDifferentialEquation(ts); 
    % f.add(next(q2) == q2 + ts * 1/2 * omega_ref_x);           
    
    %% Define optimal control problem (see page 29 in ACADO MATLAB manual)
    %ocp = acado.OCP(0.0, tEnd, N); % note that if the time is optimized, the output time will be normalized between [0:1]
    ocp = acado.OCP(0.0, N*ts, N);   
    
    % Define intermediate states and errors used in cost
    velocity = acado.IntermediateState(sqrt(dx*dx + dy*dy));
    %velocity_matching = acado.IntermediateState(velocity - ds); % maybe this can be left out ?? this works similarly to the lag error (longitudinal matching in the racecar MPC)
    %velocity_error = velocity - desiredVelocity;
    
    % Heading definitions
    %dx_ref = acado.IntermediateState(11*cx11*s_^10 + 10*cx10*s_^9 + 9*cx9*s_^8 + 8*cx8*s_^7 + 7*cx7*s_^6 + 6*cx6*s_^5 + 5*cx5*s_^4 + 4*cx4*s_^3 + 3*cx3*s_^2 + 2*cx2*s_ + cx1);
    %dy_ref = acado.IntermediateState(11*cy11*s_^10 + 10*cy10*s_^9 + 9*cy9*s_^8 + 8*cy8*s_^7 + 7*cy7*s_^6 + 6*cy6*s_^5 + 5*cy5*s_^4 + 4*cy4*s_^3 + 3*cy3*s_^2 + 2*cy2*s_ + cy1);    
    dx_ref = acado.IntermediateState(9*cx9*s_^8 + 8*cx8*s_^7 + 7*cx7*s_^6 + 6*cx6*s_^5 + 5*cx5*s_^4 + 4*cx4*s_^3 + 3*cx3*s_^2 + 2*cx2*s_ + cx1);
    dy_ref = acado.IntermediateState(9*cy9*s_^8 + 8*cy8*s_^7 + 7*cy7*s_^6 + 6*cy6*s_^5 + 5*cy5*s_^4 + 4*cy4*s_^3 + 3*cy3*s_^2 + 2*cy2*s_ + cy1);    
    % yaw_ref = atan2(dy_ref, dx_ref); % instead of using this we replace using the relationships
    %   cos(atan2(y,x)) = x / sqrt(x^2+y^2)
    %   sin(atan2(y,x)) = y / sqrt(x^2+y^2)
    % In our case this eg. becomes
    %   cos(yaw_ref) = cos(atan2(dy_ref, dx_ref)) = dx_ref / sqrt(dx_ref^2 + dy_ref^2)
    %   sin(yaw_ref) = sin(atan2(dy_ref, dx_ref)) = dy_ref / sqrt(dx_ref^2 + dy_ref^2)    
    cos_yaw_ref = acado.IntermediateState(dx_ref / sqrt(dx_ref^2 + dy_ref^2));
    sin_yaw_ref = acado.IntermediateState(dy_ref / sqrt(dx_ref^2 + dy_ref^2));
    
    % Lateral and longitudinal error
    x_err = acado.IntermediateState(x - x_ref);
    y_err = acado.IntermediateState(y - y_ref);  
    
    lateral_deviation = acado.IntermediateState(sin_yaw_ref * x_err - cos_yaw_ref * y_err);  % positive towards right
    longitudinal_velocity = acado.IntermediateState(cos_yaw_ref * dx + sin_yaw_ref * dy);  
    velocity_matching = acado.IntermediateState(longitudinal_velocity - ds);
    lag_error = acado.IntermediateState(-cos_yaw_ref * x_err - sin_yaw_ref * y_err);
    %lag_error = -cos_yaw_ref * x_err - sin_yaw_ref * y_err;    
    %tubeCenter = (tubeLeft + tubeRight) / 2;
    %contouring_error_centered = contouring_error - tubeCenter;
    velocity_error = acado.IntermediateState(longitudinal_velocity - maxVelocity); % oddly enough this seems to give better performance, by punishing the MPC to be away from maximum velocity
    
%     tube_left_approaching = acado.IntermediateState(exp((tubeLeft-lateral_deviation)*6));
%     tube_right_approaching = acado.IntermediateState(exp((lateral_deviation-tubeRight)*6));
%     tube_approaching = acado.IntermediateState(tube_left_approaching + tube_right_approaching);

    proximityObstacle1 = acado.IntermediateState( sqrt( (x - obs1_x)*(x - obs1_x) + (y - obs1_y)*(y - obs1_y) ) - obs1_r );
    proximityObstacle2 = acado.IntermediateState( sqrt( (x - obs2_x)*(x - obs2_x) + (y - obs2_y)*(y - obs2_y) ) - obs2_r );
    proximityObstacle3 = acado.IntermediateState( sqrt( (x - obs3_x)*(x - obs3_x) + (y - obs3_y)*(y - obs3_y) ) - obs3_r );
    proximityObstacle4 = acado.IntermediateState( sqrt( (x - obs4_x)*(x - obs4_x) + (y - obs4_y)*(y - obs4_y) ) - obs4_r );
    proximityObstacle5 = acado.IntermediateState( sqrt( (x - obs5_x)*(x - obs5_x) + (y - obs5_y)*(y - obs5_y) ) - obs5_r );    

    %h = [diffStates; controls]; % 'diffStates' and 'controls' are automatically defined by ACADO
    %hN = [diffStates]; 
    h = [x_err;y_err; q2;q3;  omega_ref_x;omega_ref_y;  velocity_matching; velocity_error;   domega_ref_x;domega_ref_y;   velocity_slack_variable;proximity_slack_variable];
    hN = [x_err;y_err; q2;q3;  omega_ref_x;omega_ref_y;  velocity_matching; velocity_error ];
    W = acado.BMatrix(eye(length(h))); % Cost-function weighting matrix
    WN = acado.BMatrix(eye(length(hN)));
    
    Slx = acado.BVector(eye(10,1));  % [0,0,0,0,0,0,0,-gamma]  :  the ratio between gamma and q_c controls the trade off between maximum progress (large gamma) and tight path following (large q_c)  -- q_l should be chosen high
    Slu = acado.BVector(eye(6, 1));    
    
    ocp.minimizeLSQ(W, h);   % W = diag([q_c, q_l, Ru_x, Ru_y, Rv])
    ocp.minimizeLSQEndTerm(WN, hN);
    %ocp.minimizeLSQLinearTerms(Slx, Slu);
    %ocp.minimizeLSQ({q2,q3}); % min(q2^2 + q3^2)
    %ocp.minimizeLagrangeTerm( omeg_ref_x*omeg_ref_x + omeg_ref_y*omeg_ref_y ); % Lagrange terms are on the whole sequence    
    %ocp.minimizeMayerTerm( x ); % Mayer terms are only the final state, control input etc.
    
    %ocp.subjectTo( f );
    ocp.setModel( f );  
    
    %% Define final-state requirements    
     ocp.subjectTo( 'AT_END', q2 == 0 );
     ocp.subjectTo( 'AT_END', q3 == 0 );    
     
     ocp.subjectTo( 'AT_END', omega_ref_x == 0 );
     ocp.subjectTo( 'AT_END', omega_ref_y == 0 );      
% 
%     ocp.subjectTo( 'AT_END', dx == 0 );
%     ocp.subjectTo( 'AT_END', dy == 0 );
    
    %% Define constraints
    quaternion_max = acado.IntermediateState( sin(1/2*(maxAngle)) ); %  + angle_slack_variable
    ocp.subjectTo( q2 - quaternion_max <= 0 );  % q2 <= sin(1/2*maxAngle)
    ocp.subjectTo( -q2 - quaternion_max <= 0 ); % -q2 <= sin(1/2*maxAngle)  --->  q2 >= -sin(1/2*maxAngle)
    ocp.subjectTo( q3 - quaternion_max <= 0 );  % q3 <= sin(1/2*maxAngle)
    ocp.subjectTo( -q3 - quaternion_max <= 0 ); % -q3 <= sin(1/2*maxAngle)  --->  q2 >= -sin(1/2*maxAngle)
    %ocp.subjectTo( angle_slack_variable >= 0 );
    %ocp.subjectTo( angle_slack_variable - pi/2 + maxAngle <= 0 );
    
    ocp.subjectTo( omega_ref_x - maxOmegaRef <= 0 ); % omega_ref_x <= maxOmegaRef
    ocp.subjectTo( -omega_ref_x - maxOmegaRef <= 0 ); % omega_ref_x >= -maxOmegaRef
    ocp.subjectTo( omega_ref_y - maxOmegaRef <= 0 ); % omega_ref_x <= maxOmegaRef
    ocp.subjectTo( -omega_ref_y - maxOmegaRef <= 0 ); % omega_ref_x >= -maxOmegaRef    

    %ocp.subjectTo( ds >= 0 );       
    %ocp.subjectTo( ds - desiredVelocity <= 0 );
    %ocp.subjectTo( velocity >= 0 );    
    ocp.subjectTo( velocity - desiredVelocity - velocity_slack_variable <= 0 ); %  oddly enough, by putting the constraint on the desired velocity, we end up driving on the constraint boundary, since the cost function will try to push the velocity beyond the constraint at all times
    %ocp.subjectTo( velocity_slack_variable >= 0 );
    
    ocp.subjectTo( s_ - trajectoryLength <= 0 ); % s_ <= trajectoryLength
    ocp.subjectTo( s_ >= 0 ); % s_ >= 0         
    
    ocp.subjectTo( proximityObstacle1 + proximity_slack_variable >= 0 );
    ocp.subjectTo( proximityObstacle2 + proximity_slack_variable >= 0 );
    ocp.subjectTo( proximityObstacle3 + proximity_slack_variable >= 0 );
    ocp.subjectTo( proximityObstacle4 + proximity_slack_variable >= 0 );
    ocp.subjectTo( proximityObstacle5 + proximity_slack_variable >= 0 );
    ocp.subjectTo( proximity_slack_variable >= 0 );
    
%     ocp.subjectTo( contouring_error - tubeLeft + tube_left_slack_variable >= 0 );  %  % contouring_error >= -0.5
%     ocp.subjectTo( contouring_error - tubeRight - tube_right_slack_variable <= 0 ); %   % contouring_error <= 0.5     
%     ocp.subjectTo( tube_left_slack_variable >= 0 );
%     ocp.subjectTo( tube_right_slack_variable >= 0 );

    %% Create and configure ACADO optimization algorithm
    %algo = acado.OptimizationAlgorithm(ocp);   
    %algo.set('KKT_TOLERANCE', 1e-10); % Set a custom KKT tolerance
        
    mpc = acado.OCPexport( ocp );
    % All possible parameters are defined here: http://acado.sourceforge.net/matlab/doc/html/matlab/acado/packages/+acado/@OptimizationAlgorithmBase/set.html
    mpc.set( 'HESSIAN_APPROXIMATION',       'GAUSS_NEWTON'      );
    mpc.set( 'DISCRETIZATION_TYPE',         'MULTIPLE_SHOOTING' );
    mpc.set( 'SPARSE_QP_SOLUTION',          'FULL_CONDENSING_N2');  % FULL_CONDENSING, FULL_CONDENSING_N2
    mpc.set( 'INTEGRATOR_TYPE',             'INT_IRK_GL2'       );  % INT_RK45, INT_IRK_GL2, INT_IRK_GL4
    mpc.set( 'NUM_INTEGRATOR_STEPS',        3*N                 );
    mpc.set( 'QP_SOLVER',                   'QP_QPOASES3'    	);
    mpc.set( 'LEVENBERG_MARQUARDT',         1e-10                );    
    mpc.set( 'HOTSTART_QP',                 'YES'             	);   
    %mpc.set( 'CG_HARDCODE_CONSTRAINT_VALUES','YES'             	);    % Specifies whether to hard-code the constraint values.  Works only for box constraints on control and differential state variables.
    mpc.set( 'FIX_INITIAL_STATE',            'YES'             	);     % should be set to YES for MPC
    %mpc.set( 'GENERATE_MATLAB_INTERFACE', 'YES'               );     
    %mpc.set( 'GENERATE_SIMULINK_INTERFACE', 'YES'               );     
    %mpc.set( 'CG_USE_VARIABLE_WEIGHTING_MATRIX', 'YES'       );   % allow different weighting matrices for each stage in the horizon (1:(N+1))    
    
    %mpc.set('USE_SINGLE_PRECISION', 'BT_TRUE');
    
%     mpc.set( 'HESSIAN_APPROXIMATION',       'GAUSS_NEWTON'      );
%     mpc.set( 'DISCRETIZATION_TYPE',         'MULTIPLE_SHOOTING' );
%     mpc.set( 'SPARSE_QP_SOLUTION',          'FULL_CONDENSING_N2'); % FULL_CONDENSING, FULL_CONDENSING_N2
%     mpc.set( 'INTEGRATOR_TYPE',             'INT_IRK_GL4'       ); % INT_RK45, INT_IRK_GL4
%     mpc.set( 'NUM_INTEGRATOR_STEPS',         3*N                );
%     mpc.set( 'QP_SOLVER',                   'QP_QPOASES3'    	);
%     mpc.set( 'HOTSTART_QP',                 'YES'             	);
%     mpc.set( 'LEVENBERG_MARQUARDT', 		 1e-10				);
%     mpc.set( 'CG_HARDCODE_CONSTRAINT_VALUES','YES'             	);
%     mpc.set( 'FIX_INITIAL_STATE',            'YES'             	);
%     % mpc.set('KKT_TOLERANCE',1e-10)
%     % mpc.set('MAX_NUM_ITERATIONS ',100)    

% mpc.set ( 'HESSIAN_APPROXIMATION' , 'GAUSS_NEWTON' ); % solving algorithm
% mpc.set ( 'DISCRETIZATION_TYPE' , 'MULTIPLE_SHOOTING' ); %  Discretization algorithm
% mpc.set ( 'INTEGRATOR_TYPE' , 'INT_RK4' ) ; % Intergation algorithm
% mpc.set ( 'NUM_INTEGRATOR_STEPS' , 250) ; % Number of integration steps
% mpc.set ( 'SPARSE_QP_SOLUTION' , 'FULL_CONDENSING_N2' );
% mpc.set ( 'FIX_INITIAL_STATE' , 'YES' );
% mpc.set ( 'HOTSTART_QP' , 'YES' );
% mpc.set ( 'GENERATE_TEST_FILE' , 'YES' );          

    mpc.exportCode( 'kugle_mpc_export' );
    mpc.printDimensionsQP();        
    global ACADO_;
    ACADO_.helper
    copyfile([ACADO_.pwd '/../../external_packages/qpoases3'], 'kugle_mpc_export/qpoases3')
    cd('kugle_mpc_export');      
    copyfile('../acado_solver_mex_thomas.c', 'acado_solver_mex.c');
    make_acado_solver
    copyfile('acado_solver.mex*', '../')
    %WriteArrayIndexFile()
    cd('..');
    
    MPCparameters.ts = ts;
    MPCparameters.N = N;
    save('MPCparameters.mat', 'MPCparameters');
    
    return;
    pause(1.0);
    
    %eval(sprintf(regexprep(ACADO_.mexcall, '\\', '\\\\'), "kugle_mpc_export.cpp", "kugle_mpc_export_RUN"));
    
    cd('kugle_mpc_export');
    copyfile('../make_custom_solver_sfunction.m', 'make_custom_solver_sfunction.m');
    copyfile('../acado_solver_sfun.c', 'acado_solver_sfun.c');
    %make_acado_solver_sfunction
    make_custom_solver_sfunction
    copyfile('acado_solver_sfun.mex*', '../')
    cd('..');
    
    make_ACADO_MPC_MEX

%clear;

%% Configuration parameters for test
N = 50;
xInit = [0,0,  2,1,  0,0]';
uInit = [0,0]';
Wmat = eye(4);
WNmat = eye(2);
ref0 = [0,0, 0,0];
refInit = repmat(ref0, [N+1,1]);
maxAngle = deg2rad(10);
maxOmegaRef = deg2rad(30);
xFinal = 0;
yFinal = 0;
od0 = [maxAngle, maxOmegaRef, xFinal, yFinal];
odInit = repmat(od0, [N+1,1]);

%% Test MPC with regular MATLAB interface
clear acado_input;
acado_input.od = odInit; % Online data
acado_input.W = Wmat;
acado_input.WN = WNmat;
acado_input.x = repmat(xInit', [N+1,1]);
acado_input.x0 = xInit';
acado_input.y = refInit(1:N, :);
acado_input.yN = refInit(N+1, 1:2);
acado_input.u = repmat(uInit', [N,1]); % Set initial inputs to zero

tic;
acado_output = acado_solver(acado_input);
toc;

%% Test the MPC
ACADO_MPC_MEX(0, xInit, uInit, Wmat, WNmat, refInit, odInit)

x = xInit;
ref = refInit;
od = odInit;
nIter = 1;

tic;
[u0, xTraj, uTraj, kktTol, status, nIter, objVal] = ACADO_MPC_MEX(1, x, ref, od, nIter)
toc;

% Compare the two compiled program outputs
acado_output.x == xTraj

% Visualize
figure(2);
plot(xTraj(:,3));
hold on;
plot(xTraj(:,4));
hold off;
