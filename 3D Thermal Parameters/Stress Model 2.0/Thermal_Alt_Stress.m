% This program uses the resistance network concept to solve for the
% temperatures and stresses due to CTE mismatch in an electronic component
% module
% Establish global variables
global NL NR NC h Mat kond dx dy dz A B Ta Q cte E nu
% Input parameters
NL=7; % # of layers in the model
NR=12; % # of rows in the model
NC=12; % # of columns in the model
% Convection coefficients for the left, right, front, back, top and bottom
% of the model, W/m^2 K
% For an adiabatic or symmetry boundary enter 0
h=[0 0 0 0 20000 0];
% Ambient or sink temperature for the left, right, front, back, top and bottom
% of the model, C
Ta=[20 20 20 20 20 20];
Q=zeros(NR,NC,NL); % Nodal heat generation matrix, W
Mat=zeros(NR,NC,NL); % Nodal material matrix
Tres=zeros(NR,NC,NL); % Nodal temperature results
Tprnt=zeros(NR,NC,NL); % Nodal temperature results realigned to match mesh layout
Lfx=zeros(NR,NC); % Final element length in x-dir due to cte mismatch
Lfy=zeros(NR,NC); % Final element length in y-dir due to cte mismatch
StressX=zeros(NR,NC,NL); % Nodal thermal stress results in x-dir
StrprntX=zeros(NR,NC,NL); % Nodal stress results in x-dir realigned to match mesh layout
StressY=zeros(NR,NC,NL); % Nodal thermal stress results in x-dir
StrprntY=zeros(NR,NC,NL); % Nodal stress results in x-dir realigned to match mesh layout
SumForce=zeros(NR,NC);
Force=zeros(NR,NC,NL);
% Material conductivity vector, W/m K, load value for each material
% Materials are Al, Cu, AlN, SiC
kond=[170 170 390 160 120];
% Material CTE vector, m/m K, load value for each material
% Materials are Al, Cu, AlN, SiC
cte=[24.0e-6 24.0e-6 24.0e-6 4.9e-6 4.0e-6];
% Young's modulus vector, N/m^2, load value for each material
% Materials are Al, Cu, AlN, SiC
E=[69e9 69e9 110e9 330e9 410e9];
% Poisson's ratio vector, load value for each material
% Materials are Al, Cu, AlN, SiC
nu=[0.33 0.33 0.37 0.24 0.14];
Tproc=217;
dx=[.002 .00267 .00267 .00267 .002 .003 .003 .002 .00267 .00267 .00267 .002]; % Column width vector, m, load value for each column
dy=[.002 .00267 .00267 .00267 .002 .003 .003 .002 .00267 .00267 .00267 .002]; % Row height vector, m, load value for each row
% Layer thickness vector, m, load value for each layer
dz=[.005 .005 .0003 .00064 .0003 .0004 .0001];
% Load the Q matrix
% Replace ii,jj,kk with corresponding row, column and layer values and replace q with the heat generation, W
Q(2:4,2:4,7)=8.889;
Q(2:4,9:11,7)=8.889;
Q(9:11,2:4,7)=8.889;
Q(9:11,9:11,7)=8.889;
% Load the Mat matrix
% Replace ii,jj,kk with corresponding row, column and layer values and replace m with the material designation
% Enter a 0 for a location that does not have any material present
Mat(:,:,1)=1; 
Mat(:,:,2)=2; 
Mat(:,:,3)=3;
Mat(:,:,4)=4;
Mat(:,:,5)=3;
Mat(1:5,6:7,5)=0;
Mat(6:7,:,5)=0;
Mat(2:4,2:4,6)=5;
Mat(2:4,9:11,6)=5;
Mat(9:11,2:4,6)=5;
Mat(9:11,9:11,6)=5;
Mat(2:4,2:4,7)=5;
Mat(2:4,9:11,7)=5;
Mat(9:11,2:4,7)=5;
Mat(9:11,9:11,7)=5;
A=zeros(NR*NC*NL,NR*NC*NL); % Conductance matrix in [A](T)={B}
B=zeros(NR*NC*NL,1); % Constants vector in [A](T)={B}
% Load A matrix and B vector for left face nodes
LeftFace
% Load A matrix and B vector for right face nodes
RightFace
% Load A matrix and B vector for front face nodes
FrontFace
% Load A matrix and B vector for back face nodes
BackFace
% Load A matrix and B vector for bottom face nodes
BottomFace
% Load A matrix and B vector for top face nodes
TopFace
% Load A matrix and B for the interior nodes
Interior
% Adjust the A matrix and B vector for locations where there is no material
% For the A matrix set the diagonal to 1.0 other columns to 0.0 for the
% particular row, for the B vector set the row to -1
for kk=1:NL
    for ii=1:NR
        for jj=1:NC
            if Mat(ii,jj,kk) == 0
            Ind=(kk-1)*NR*NC+(ii-1)*NC+jj;
            A(Ind,:)=0;
            A(Ind,Ind)=1.0;
            B(Ind)=-1;
            end
        end
    end
end
T=A\B;
% Load Temperature results matrix that reflects layer by layer position of
% the nodes
for kk=1:NL
    for ii=1:NR
        for jj=1:NC
            Ind=(kk-1)*NR*NC+(ii-1)*NC+jj;
            Tres(ii,jj,kk)=T(Ind);
            % Makes the temperatures print in the same order as nodes for
            % any partucular layer
            Tprnt(NR+1-ii,jj,kk)=T(Ind);
        end
    end
end
% Calculate thermal stress based on CTE mismatch
% Calculate the difference between the operating and processing
% temperatures
delT=Tres-Tproc;
% Loop over all elements to claculate stress due to CTE mismatch for each
% element
for kk=1:NL
    % Loop over all rows and columns to determine the final x and y lengths of
    % the elements
    for ii=1:NR
        for jj=1:NC
            Lfx(ii,jj)=L_final_x(ii,jj,delT(ii,jj,:));
            Lfy(ii,jj)=L_final_y(ii,jj,delT(ii,jj,:));
            % Calcualte stress for each element
            StressX(ii,jj,kk)=Stress(Lfx(ii,jj),dx(jj),ii,jj,kk,delT(ii,jj,kk));
            StressY(ii,jj,kk)=Stress(Lfy(ii,jj),dy(ii),ii,jj,kk,delT(ii,jj,kk));
        end
    end
end
for kk=1:NL
    for ii=1:NR
        for jj=1:NC
            % Makes the stresses print in the same order as nodes for
            % any partucular layer
            StrprntX(NR+1-ii,jj,kk)=StressX(ii,jj,kk);
            StrprntY(NR+1-ii,jj,kk)=StressY(ii,jj,kk);
        end
    end
end
% Stress check, sum forces to be sure they go to zero
for ii=1:NR
    for jj=1:NC
        for kk=1:NL
            Force(ii,jj,kk)=StressX(ii,jj,kk)*dy(ii)*dz(kk);
            SumForce(ii,jj)=SumForce(ii,jj)+StressX(ii,jj,kk)*dy(ii)*dz(kk);
        end
    end
end
