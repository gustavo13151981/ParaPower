function ModelInput=FormModel(TestCaseModel)
%disp('============================')

%Overall structures orientation/BCs for ease of reference
Left  = 1; %X- Face
Right = 2; %X+ Face
Front = 3; %Y- Face
Back  = 4; %Y+ Face
Bottom= 5; %Z- Face
Top   = 6; %Z+ Face

if ischar(TestCaseModel) 
    if strcmpi('GetDirex',TestCaseModel) %this argument will return the directional index definitions
        ModelInput.Left=Left;
        ModelInput.Right=Right;
        ModelInput.Front=Front;
        ModelInput.Back=Back;
        ModelInput.Bottom=Bottom;
        ModelInput.Top=Top;
        return
    else
        error('Invalid optional argument');
    end
else
    if not(isfield(TestCaseModel,'Version')) 
        error(['Incorrect TestCaseModel version.  No version is specified']);
    elseif not(strcmpi(TestCaseModel.Version,'V2.0'))
        error(['Incorrect TestCaseModel version.  V2.0 required, this data is ' TestCaseModel.Version]);
    end
    ExternalConditions=TestCaseModel.ExternalConditions;
    Features=TestCaseModel.Features;
    Params=TestCaseModel.Params;
    PottingMaterial=TestCaseModel.PottingMaterial;
end

%Material Properties
if isfield(TestCaseModel,'MatLib')
    MatLib=TestCaseModel.MatLib;
else
    warning('MatLib needs to be included in the TestCaseModel structure')
    msgbox('MatLib needs to be included in the TestCaseModel structure','Warning');
    return
end
%[matprops, matlist, matcolors, kond, cte,E,nu,rho,spht]=matlibfun;


h(Left)=ExternalConditions.h_Left;
h(Right)=ExternalConditions.h_Right;
h(Front)=ExternalConditions.h_Front;
h(Back)=ExternalConditions.h_Back;
h(Top)=ExternalConditions.h_Top;
h(Bottom)=ExternalConditions.h_Bottom;

Ta(Left)=ExternalConditions.Ta_Left;
Ta(Right)=ExternalConditions.Ta_Right;
Ta(Front)=ExternalConditions.Ta_Front;
Ta(Back)=ExternalConditions.Ta_Back;
Ta(Top)=ExternalConditions.Ta_Top;
Ta(Bottom)=ExternalConditions.Ta_Bottom;

Tproc=ExternalConditions.Tproc;


%Construct dx, dy, dz
X=[];  %X coordinates 
Y=[];  %Y coordinates
Z=[];  %Z coordinates
X0=[]; %Z coordinates with zero thickness
Y0=[]; %Z coordinates with zero thickness
Z0=[]; %Z coordinates with zero thickness

%Go through features list and determine if it's a zero thickness in any
%direction. Build up X, Y, Z list of coordinates and X0, Y0, Z0 which is
%the special list that covers zero thickness features.

for i=1:length(Features)
    Fd=Features(i).x;
    if isscalar(Fd)
        Fd=[1 1]*Fd;
    end
    Features(i).x=Fd;
    
    Fd=Features(i).y;
    if isscalar(Fd)
        Fd=[1 1]*Fd;
    end
    Features(i).y=Fd;

    Fd=Features(i).z;
    if isscalar(Fd)
        Fd=[1 1]*Fd;
    end
    Features(i).z=Fd;
    
    Features(i).x=sort(Features(i).x);
    Features(i).y=sort(Features(i).y);
    Features(i).z=sort(Features(i).z);
    if Features(i).x(1)==Features(i).x(2) %Acount for special case of zero height layer
        X0=[X0 Features(i).x(1)];
        X=[X Features(i).x(1)];
    else
        X=[X linspace(Features(i).x(1), Features(i).x(2), 1+Features(i).dx)];
    end
    if Features(i).y(1)==Features(i).y(2) %Acount for special case of zero height layer
        Y0=[Y0 Features(i).y(1)];
        Y=[Y Features(i).y(1)];
    else
        Y=[Y linspace(Features(i).y(1), Features(i).y(2), 1+Features(i).dy)];
    end
    if Features(i).z(1)==Features(i).z(2) %Acount for special case of zero height layer
        Z0=[Z0 Features(i).z(1)];
        Z=[Z Features(i).z(1)];
    else
        Z=[Z linspace(Features(i).z(1), Features(i).z(2), 1+Features(i).dz)];
    end
end

%Collapse X and y completely.  Maintain zero thickness layers for dz
%Fix floating point inaccuracies.  Round to accuracy of epsilon - 2
%decimals
if ~isempty(X0)
    X0=unique(round(X0,floor(abs(log10(100*eps(max(X0)))))));
end
if ~isempty(Y0)
    Y0=unique(round(Y0,floor(abs(log10(100*eps(max(Y0)))))));
end
if ~isempty(Z0)
    Z0=unique(round(Z0,floor(abs(log10(100*eps(max(Z0)))))));
end
X=unique(round(X,floor(abs(log10(100*eps(max(X)))))));
Y=unique(round(Y,floor(abs(log10(100*eps(max(Y)))))));
Z=unique(round(Z,floor(abs(log10(100*eps(max(Z)))))));

X=sort([X X0]); 
Y=sort([Y Y0]); 
Z=sort([Z Z0]); 

%Create list of final Delta coordinates that will be used to generate
%model.
DeltaCoord.X=X(2:end)-X(1:end-1);
DeltaCoord.Y=Y(2:end)-Y(1:end-1);
DeltaCoord.Z=Z(2:end)-Z(1:end-1);

OriginPoint=[min(X) min(Y) min(Z)]; %Record minimum absolute coords of X Y and Z

Params.Tsteps=floor(Params.Tsteps);

%Create model matrix that will hold material/feature number for each delta coord
%ModelMatrix=nan*zeros(length(X)-1,length(Y)-1,length(Z)-1);
ModelMatrix=nan*zeros(length(DeltaCoord.X),length(DeltaCoord.Y),length(DeltaCoord.Z));

%Q=zeros([size(ModelMatrix) Params.Tsteps]);
S=size(ModelMatrix);
if length(S)<3
    error(['Model cannot be planar. It must have a minimum of 2 elements in each direction.'])
end
Q=cell(S);
%Q=zeros([size(ModelMatrix) Params.Tsteps]);

if isempty(Params.Tsteps)
    GlobalTime=[];
else
    GlobalTime=[0:Params.DeltaT:(Params.Tsteps)*Params.DeltaT];
end

%Get minimum values of feature coords for visualization purposes.
MinCoord=[min(X) min(Y) min(Z)];

%MODIFY ALGORTHM as follows.
%Initilize model matrix to NaN
%Loop through features with non-zero thickness in any direction
%Loop thorugh features with zero thickness and apply non-feature areas as above or below material
%Set all NaN elements to potting material

%Identify all zero-thickness and non-zero-thickness features
ZeroThickness=[];
NonZeroThickness=[];
for Fi=1:length(Features)
    if any([ isscalar(unique(Features(Fi).x)) ...
             isscalar(unique(Features(Fi).y)) ...
             isscalar(unique(Features(Fi).z)) ])
         ZeroThickness(end+1)=Fi;
    else
         NonZeroThickness(end+1)=Fi;
    end
end


%Apply Feature number for non-zero thickness elements
for Fii=1:length(NonZeroThickness) 
    Fi=NonZeroThickness(Fii);
    InX=GetInXYZ(Features(Fi).x, X);
    InY=GetInXYZ(Features(Fi).y, Y);
    InZ=GetInXYZ(Features(Fi).z, Z);
    
    AllNaN=all(isnan(reshape(ModelMatrix(InX,InY,InZ),1,[])));
%     if not(AllNaN)
%         warning(['Some solid features overlap.  Behavior for this condition is undefined and may result in incorrect results. (Feature #' num2str(Fi) ')'])
%     end
    ModelMatrix(InX, InY, InZ)=Fi;
end

%Apply Feature number for zero-thickness elements
for Fii=1:length(ZeroThickness) 
    Fi=ZeroThickness(Fii);
    InX=GetInXYZ(Features(Fi).x, X);
    InY=GetInXYZ(Features(Fi).y, Y);
    InZ=GetInXYZ(Features(Fi).z, Z);
    
    AllNaN=all(isnan(reshape(ModelMatrix(InX,InY,InZ),1,[])));
%     if not(AllNaN)
%         warning(['Some zero-thickness features overlap.  Behavior for this condition is undefined and may result in incorrect results. (Feature #' num2str(Fi) ')'])
%     end
    %Ensure that zero-thickness layer elements that are undefined as set to
    %the same mateiral as what is adjacent to eliminate discontinuities.
    %Change this predefine only for NaN elements.
    if isscalar(unique(Features(Fi).x))  %X is zero thickness
        UseLayer=GetZeroLayer(X, Features(Fi).x);
        Plane=ModelMatrix(InX,:,:);
        PlaneUse=ModelMatrix(UseLayer,:,:);
        Plane(find(isnan(Plane)))=PlaneUse(find(isnan(Plane)));
        ModelMatrix(InX,:,:)=Plane;
    %    ModelMatrix(InX,:,:)=ModelMatrix(UseLayer,:,:);
    elseif isscalar(unique(Features(Fi).y)) %y is zero thickness
        UseLayer=GetZeroLayer(Y, Features(Fi).y);
        Plane=ModelMatrix(:,InY,:);
        PlaneUse=ModelMatrix(:,UseLayer,:);
        Plane(find(isnan(Plane)))=PlaneUse(find(isnan(Plane)));
        ModelMatrix(:,InY,:)=Plane;
%        ModelMatrix(:,InY,:)=ModelMatrix(:,UseLayer,:);
    elseif isscalar(unique(Features(Fi).z)) %z is zero thickness
        UseLayer=GetZeroLayer(Z, Features(Fi).z);
        Plane=ModelMatrix(:,:,InZ);
        PlaneUse=ModelMatrix(:,:,UseLayer);
        Plane(find(isnan(Plane)))=PlaneUse(find(isnan(Plane)));
        ModelMatrix(:,:,InZ)=Plane;
        %ModelMatrix(:,:,InZ)=ModelMatrix(:,:,UseLayer);
    end
    ModelMatrix(InX, InY, InZ)=Fi;
end

%Compute volume (real) and area (imaginary) of model
VA=ComputeVA(DeltaCoord);
ScaledQ=zeros(size(ModelMatrix));

%Set elements with neither area nor volume to material type 0
ModelMatrix(VA==0)=0;

%Apply Q's (Note that Q's are now defined as function handles)
for Fi=1:length(Features)
    %Define Q for the feature
     %Negate Q so that postive Q is corresponds to heat generation
     if strcmpi(class(Features(Fi).Q),'function_handle')
         ThisQ=@(t)Features(Fi).Q(t)*(-1);
     elseif isscalar(Features(Fi).Q)
         if Features(Fi).Q==0
             ThisQ=[];
         else
            ThisQ=@(t)(-1)*Features(Fi).Q;
         end
     elseif ischar(Features(Fi).Q)
         ThisQ=@(t)eval(Features(Fi).Q)*(-1);
         try
             ThisQ(0);
         catch ErrTrap
             error(['"' Features(Fi).Q '" is not a valid function.'])
         end
     elseif isempty(Features(Fi).Q)
         ThisQ=[];
     elseif length(Features(Fi).Q(1,:))==2
         ThisQ=@(t)(-1)*interp1(Features(Fi).Q(:,1),Features(Fi).Q(:,2),t);
         GlobalTime=[GlobalTime Features(Fi).Q(:,1)'];
     else
         error(['Unknown form of Q for feature ' num2str(Fi)])
     end

     if not(isempty(ThisQ))
         %Cycle through elements for feature Fi and add their area/volume to scale Q
         Fmask=(ModelMatrix==Fi);
        
         Area=imag(VA(Fmask)); %Area elements
         Volm=real(VA(Fmask)); %Volume elements
         TotalA=sum(Area);  %Total Area for feature
         TotalV=sum(Volm);  %Total Volume for feature
         
         if TotalV==0  %If this is a zero-thickness feature
             ScaledQ(Fmask) = imag(VA(Fmask))./TotalA;
         else
             ScaledQ(Fmask) = real(VA(Fmask))./TotalV;
         end
         
         %ThisQ(t) contains the function handle from the feature definition
         %ScaledQ(Ei) contains the scalar factor of El.Area/Tot.Area or El.Vol/Tot.Vol
         
         for Ei=find(reshape(Fmask,1,[]))
             Q{Ei}=@(t)ThisQ(t)*ScaledQ(Ei);
         end
     end
end

ModelMatrix=ModelMatrix*i;  %Make all feature number imaginary, then replace "imaginary" feature numbers with "real" material numbers.
for Fi=1:length(Features)
    MatNum=find(strcmpi(Features(Fi).Matl,MatLib.Material));
    if isempty(MatNum)
        MatNum=NaN;
        fprintf('Feature %2.0f material %s is unknown',Fi,MatNum);
    end
    ModelMatrix(ModelMatrix==Fi*i)=MatNum;
end
     
if ischar(PottingMaterial)
    MatNum=find(strcmpi(PottingMaterial,lower(MatLib.Material)));
    if isempty(MatNum)
        MatNum=NaN;
        fprintf('Potting material %s is unknown',PottingMaterial);
    end
else
    MatNum=PottingMaterial;
end
ModelMatrix(isnan(ModelMatrix))=MatNum;

%[NR, NC, NL]=size(ModelMatrix);
GlobalTime = uniquetol(GlobalTime, 10*eps(max(GlobalTime)));

ModelInput.OriginPoint=OriginPoint; %Minimum absolute coordinates for X, Y and Z
ModelInput.h=h;
ModelInput.Ta=Ta;
ModelInput.X=DeltaCoord.X;
ModelInput.Y=DeltaCoord.Y;
ModelInput.Z=DeltaCoord.Z;
ModelInput.Tproc=Tproc;
ModelInput.Model=ModelMatrix;
ModelInput.Q=Q;
ModelInput.GlobalTime=GlobalTime;
ModelInput.Tinit=Params.Tinit;
ModelInput.MatLib=MatLib;
%ModelInput.matprops=MatLib.matprops;
%ModelInput.matlist=MatLib.matlist;
ModelInput.Version='V2.0';

return

function UseLayer=GetZeroLayer(Coords, FeatureCoords)
    ZeroLayer=min(find(Coords==FeatureCoords(1)));
    if ZeroLayer==1
        UseLayer=2;
    else
        UseLayer=ZeroLayer-1;
    end
return

function In=GetInXYZ(FeatureExtent, Coords)

    if FeatureExtent(1)==FeatureExtent(2)
        In=find(FeatureExtent(1)==Coords);
        In=In(1:end-1);
    else
        In=find(FeatureExtent(1) <= Coords & FeatureExtent(2) > Coords);
        if length(Coords(In))~=length(unique(Coords(In)))
            In=In(2:end);
        end
    end
return

function VA=ComputeVA(DCoord)
%Compute the volume and area of the model elements.  Volumes are R, areas are i

    %Get length of each coordinate
    Lx=length(DCoord.X);
    Ly=length(DCoord.Y);
    Lz=length(DCoord.Z);
    
    %Matrix multiply Nx1(x) * 1xN(y), then reshape and Nx1(xy) * 1xN(z) then reshape into nxmxo
    VA=reshape(reshape(DCoord.X' * DCoord.Y,[],1) * DCoord.Z,Lx, Ly,[]);
    
    %Construct vector that is 0's for all non-zero elements and 1 for all Zeros
    Xz=(DCoord.X==0);
    Yz=(DCoord.Y==0);
    Zz=(DCoord.Z==0);

    %Compute (sequentially) Areas for zero thickness X, then Y, then Z
    Az=reshape(reshape(DCoord.X' * DCoord.Y,[],1) * Zz,Lx, Ly,[]);
    Ay=reshape(reshape(DCoord.X' * Yz,[],1) * DCoord.Z,Lx, Ly,[]);
    Ax=reshape(reshape(Xz' * DCoord.Y,[],1) * DCoord.Z,Lx, Ly,[]);

    %Combine the areas of the zero thickness elements and make them imag.
    VA=VA + (Ax+Ay+Az)*i;