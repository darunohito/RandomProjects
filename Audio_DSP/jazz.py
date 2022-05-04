from pynput.keyboard import Key, Listener
import numpy as np
import math as m
import time
import simpleaudio as sa


class Jazz:
    
    def __init__(self, fs=44100, f_a4=440):
        f_log = np.ndarry([120,1]) # 120 notes between nominal 20 and 20000 Hz
        f_min_log = m.log(f_a4,2)-(52/12) # 52 notes is roughly the spacing between 20Hz and 440Hz
        f_log = np.linspace(0,(120-1)/12,120) + f_min_log
        
        self.f_scale = 2**f_log
        self.tempo = 100


    def note(self, freq, len, harm3_lvl=0, harm5_lvl=0, mode='real', start_phase=0, ret_phase=False):
    
        fund_level = 1 / (1 + harm3_lvl + harm5_lvl)
        
        t = np.linspace(0,len,int(len*fs),False)
        data_i = fund_level * np.sin(2*np.pi*freq*t + start_phase) + harm3_lvl * np.sin(6*np.pi*freq*t + start_phase) + harm5_lvl * np.sin(10*np.pi*freq*t + start_phase)
        if mode == 'real' and not ret_phase
            return data_i
        elif mode == 'real' and ret_phase
            end_phase = 2*np.pi*freq*t[-1]
            return data_i, end_phase
        elif mode == 'complex'
            data_q = -fund_level * np.cos(2*np.pi*freq*t + start_phase) - harm3_lvl * np.cos(6*np.pi*freq*t + start_phase) - harm5_lvl * np.cos(10*np.pi*freq*t + start_phase)
            return data_i, data_q
        else
            print(f'"mode" argument of {mode} in note function invalid')
            exit(1)

    
    
    
if __name__ == "__main__":

    Jazz gen()
    
    t0 = time.perf_counter()
    while True:
        
    
    