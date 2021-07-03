clear all
fs = 10000; %hz, sampling frequency
%%%%%%%%%% filter 1
f1 = [0.01 0.2 1.25 1.5]*1000;
a = [0 .972 0];
[n,fo,ao,w] = firpmord(f1,a,[0.01 0.056 0.01],fs);
b1 = firpm(n,fo,ao,w);
[Hr1, f] = freqz(b1,1,n);
figure(1), subplot(2,3,[1,2,3]), plot(f*fs/2/pi,abs(Hr1))
subplot(2,3,4), plot(f*fs/2/pi,abs(Hr1)), xlim([0 15]);
subplot(2,3,5), plot(f*fs/2/pi,abs(Hr1)), xlim([175 1275]);
subplot(2,3,6), plot(f*fs/2/pi,abs(Hr1)), xlim([1475 1800]);
figure(2), zplane(b1,1)
%%%%%%%%%% filter 2
f2 = [1 1.5]*1000;
a = [0 .972];
[n,fo,ao,w] = firpmord(f2,a,[0.01 0.03],fs);
b2 = firpm(n,fo,ao,w);
[Hr2, f] = freqz(b2,1,n);
figure(3), subplot(2,2,[1,2]), plot(f*fs/2/pi,abs(Hr2))
subplot(2,2,3), plot(f*fs/2/pi,abs(Hr2)), xlim([0 1050]);
subplot(2,2,4), plot(f*fs/2/pi,abs(Hr2)), xlim([1400 3000]);
figure(4), zplane(b2,1)
%%%%%%%%%% round and create filter struct
for i = 1:length(Hr1)
 Hr1(i) = round(32767 * Hr1(i));
end
H1 = dfilt.dffir(Hr1);
for i = 1:length(Hr2)
 Hr2(i) = round(32767 * Hr2(i));
end
H2 = dfilt.dffir(Hr2);
%%%%%%%%%% create chirp
t = [0:1/fs:20];
y = chirp(t,0,20,5000);
for i = 1:length(y)
 y(i) = round(2047 * y(i));
end
%y1 = conv( y,Hr1 ); figure(5),plot(t,y1(1:length(t)))
%y2 = conv( y,Hr2 ); figure(6),plot(t,y2(1:length(t)))
y1 = filter( H1,y ); figure(5),plot(t,y1)
y2 = filter( H2,y ); figure(6),plot(t,y2)