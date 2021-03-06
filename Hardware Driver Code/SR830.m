%% SR830 lock-in amplifier wrapper
%   Version : Release
%   Author  : Patrick Parkinson (patrick.parkinson@manchester.ac.uk)
%
%   This code uses a COM-port connection to the SR830 lock-in amplifier.
%
%   Usage - taking and displaying a value:
%       li = SR830();
%       x = li.x;
%
classdef SR830 < handle
   
    %%%%%%%%%% Properties
    properties
        port='COM15';
    end 
    
    properties (Access = private)
        % Internal connections
        connected
        connection
    end 
    
    properties (Dependent=true, SetAccess = private)
        % Readable numbers
        frequency
        aux
        x
        y
        r
        theta
        sensitivity
    end 
    
%% Hidden methods   
    methods (Access = protected, Hidden=true)
        
        function o = query(obj,string)
            % Send and recieve
            fprintf(obj.connection,string);
            o = fscanf(obj.connection,'%s');
        end
        
        function send(obj,string)
            % Send a command
            fprintf(obj.connection,string);
        end
        
    end 
    
    %% Public methods 
    methods
        
        function obj=SR830(port)
            % Initialiser
            if nargin > 0
                obj.port = port;
            end
            obj.connection = serial(obj.port,'BaudRate',19200,'terminator','CR');
            % SET SERIAL PARAMETERS
            fopen(obj.connection);
        end
        
        function delete(obj)
            % Clean destroy/close
            fclose(obj.connection);
            delete(obj.connection);
        end % destructor
        
        function value = get.x(obj)
            value=double(sscanf(obj.query('OUTP ? 1'),'%f'));
        end
        function value = get.y(obj)
            value=double(sscanf(obj.query('OUTP ? 2'),'%f'));
         end       
        function value = get.r(obj)
            value=double(sscanf(obj.query('OUTP ? 3'),'%f'));
        end
        function value = get.theta(obj)
            value=double(sscanf(obj.query('OUTP ? 4'),'%f'));
        end
        
        function value = get.aux(obj)
            % Get all 4 auxilliary inputs
            value = zeros(4,1);
            for i=1:4
                value(i)=double(sscanf(obj.query(['OAUX ? ',int2str(i)]),'%f'));
            end
        end
        
        function value = get.sensitivity(obj)
            % Get lockin sensitivity
            value.n=uint8(sscanf(obj.query('SENS ?'),'%f'));
            l = [1 2 5];
            i = value.n+1;
            % Convert
            mult = (i-mod(i,3))/3;
            value.r=l(mod(i,3)+1)*10^(-9+mult);      
        end
        
        function [o,str] = getStatus(obj)
            % Read current lockin status
            o = uint8(sscanf(obj.query('LIAS?'),'%d'));
            str = '';
            if o>0
                if bitand(o,1);str = [str, 'Input overload '];end
                if bitand(o,2);str = [str, 'Filter overload '];end
                if bitand(o,4);str = [str, 'Output overload '];end
                if bitand(o,8);str = [str, 'Reference unlocked '];end
            end            
        end
        
        function s = snap(obj)
            % Get a simultaneous measurement of all 6 readings
            t=sscanf(obj.query('SNAP?1,2,3,4,5,6'),'%f,%f,%f,%f,%f,%f');
            s.x = t(1); s.y = t(2); s.r = t(3); s.theta = t(4); s.aux1 = t(5); s.aux2 = t(6);
        end
        
        function o = autoSnap(obj)
            % Attempt to find an optimum sensitivity
            s = obj.getStatus();
            if bitand(s,4)
                % Overloaded
                obj.send('AGAN');
                warning('SR830:autoSnap:overload','Overload detected: auto-gain carried out');
                flag=1;
                while flag
                    pause(0.1);
                    b=uint8(sscanf(obj.query('*STB?'),'%d'));
                    flag = not(bitand(b,2));
                end
            end
            pause(0.5);
            o = obj.snap();
        end
        
        function setAux(obj,port,voltage)
           port = uint8(round(port)); 
           if voltage<-10 || voltage>10
               warning('SR830:setAux:voltageOutOfRange','Voltage is out of range (-10V to +10V), it has been constrained');
               voltage = max(-10,min(10,voltage));
           end
           obj.send(['AUXV ', int2str(port),',',num2str(voltage,'%2.3f')]);
        end
        
    end % Methods
end % classdef