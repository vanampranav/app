import { useState, useEffect } from 'react';
import fire from './fire.png';
import vector635 from './vector-635.svg';
import vector from './vector.svg';

export const WhatsYourFitness = (): JSX.Element => {
  const [formData, setFormData] = useState({
    name: '',
    age: '25',
    height: '170',
    currentWeight: '25',
    targetWeight: '170',
    timeline: '3',
    timelineUnit: 'weeks',
  });
  const [isMounted, setIsMounted] = useState(false);

  useEffect(() => {
    // Trigger animation on component mount
    setIsMounted(true);
  }, []);

  const handleInputChange = (field: string, value: string) => {
    setFormData(prev => ({ ...prev, [field]: value }));
  };

  const handleTimelineUnitChange = (unit: 'weeks' | 'months') => {
    setFormData(prev => ({ ...prev, timelineUnit: unit }));
  };

  const handleContinue = () => {
    console.log('Form submitted:', formData);
  };

  return (
    <div
      className={`relative w-[393px] h-[794px] bg-[#161616] rounded-[40px_40px_0px_0px] overflow-hidden transition-all duration-500 ease-out ${isMounted ? 'translate-y-0 opacity-100' : 'translate-y-full opacity-0'}`}
    >
      <img
        className="absolute top-[13px] left-0 w-[393px] h-[724px]"
        alt="Vector"
        src={vector635}
      />

      <div className="flex flex-col w-[88px] items-start gap-2.5 p-2.5 absolute top-1.5 left-36">
        <div className="relative self-stretch w-full h-[3px] bg-primitives-color-gray-400 rounded-[200px]" />
      </div>

      <button
        className="flex w-9 h-9 items-center gap-2.5 p-1.5 absolute top-[46px] left-[31px] bg-[#ccd853] rounded-[18px] rotate-[180.00deg] cursor-pointer"
        aria-label="Go back"
        type="button"
      >
        <div className="relative w-6 h-6 aspect-[1]">
          <img
            className="absolute w-[78.14%] h-[65.65%] top-[17.17%] left-[10.94%] rotate-[-180.00deg]"
            alt="Vector"
            src={vector}
          />
        </div>
      </button>

      <div className="flex flex-col w-[341px] items-end gap-[9px] absolute top-[90px] left-[calc(50.00%_-_170px)]">
        <div className="relative self-stretch mt-[-1.00px] [font-family:'Inter-Medium',Helvetica] font-medium text-[#888888] text-sm text-right tracking-[0.28px] leading-[19.6px]">
          Step 1 of 3
        </div>

        <div className="flex flex-col h-[7px] items-start gap-2.5 relative self-stretch w-full bg-[#292929] rounded-[30px]">
          <div className="relative w-[108px] h-[7px] bg-[#ccd853] rounded-[30px_0px_0px_30px]" />
        </div>
      </div>

      <form className="flex flex-col w-[353px] items-center gap-[25px] absolute top-[162px] left-[calc(50.00%_-_176px)]">
        <div className="flex flex-col items-end gap-[26px] relative self-stretch w-full flex-[0_0_auto]">
          <div className="flex flex-col items-start gap-9 relative self-stretch w-full flex-[0_0_auto]">
            <div className="flex flex-col w-[332px] items-start gap-[9px] relative flex-[0_0_auto]">
              <div className="inline-flex items-center gap-[5px] relative flex-[0_0_auto]">
                <h1 className="relative w-fit mt-[-1.00px] [font-family:'Inter-Bold',Helvetica] font-bold text-white text-2xl tracking-[0.48px] leading-[33.6px] whitespace-nowrap">
                  Nice goal!
                </h1>

                <img className="relative w-[31px] h-[31px] object-cover" alt="Fire" src={fire} />
              </div>

              <p className="relative self-stretch [font-family:'Inter-Medium',Helvetica] font-medium text-[#999999] text-sm tracking-[0.28px] leading-[19.6px]">
                To build the best plan for you, we need a few quick details.
              </p>
            </div>

            <div className="flex flex-col items-start gap-3.5 relative self-stretch w-full flex-[0_0_auto]">
              <div className="flex flex-col items-start gap-[9px] relative self-stretch w-full flex-[0_0_auto]">
                <label
                  htmlFor="name"
                  className="relative self-stretch mt-[-1.00px] [font-family:'Inter-Regular',Helvetica] font-normal text-[#fbffdb] text-xs tracking-[0] leading-[normal]"
                >
                  Name
                </label>

                <input
                  id="name"
                  type="text"
                  value={formData.name}
                  onChange={e => handleInputChange('name', e.target.value)}
                  placeholder="Enter your name"
                  className="flex h-12 items-center justify-center gap-2.5 px-4 py-[11px] relative self-stretch w-full rounded-lg overflow-hidden border border-solid border-[#454545] [font-family:'Inter-Regular',Helvetica] font-normal text-[#595959] text-sm tracking-[0] leading-[normal] placeholder:text-[#595959] focus:border-[#ccd853] focus:outline-none"
                />
              </div>

              <div className="flex items-center gap-3.5 relative self-stretch w-full flex-[0_0_auto]">
                <div className="flex flex-col items-start gap-[9px] relative flex-1 grow">
                  <label
                    htmlFor="age"
                    className="relative self-stretch mt-[-1.00px] [font-family:'Inter-Regular',Helvetica] font-normal text-[#fbffdb] text-xs tracking-[0] leading-[normal]"
                  >
                    Age
                  </label>

                  <input
                    id="age"
                    type="number"
                    value={formData.age}
                    onChange={e => handleInputChange('age', e.target.value)}
                    className="flex h-12 items-center justify-center gap-2.5 px-4 py-[11px] relative self-stretch w-full rounded-lg overflow-hidden border border-solid border-[#454545] [font-family:'Inter-Regular',Helvetica] font-normal text-[#595959] text-sm tracking-[0] leading-[normal] focus:border-[#ccd853] focus:outline-none"
                  />
                </div>

                <div className="flex flex-col items-start gap-[9px] relative flex-1 grow">
                  <label
                    htmlFor="height"
                    className="relative self-stretch mt-[-1.00px] [font-family:'Inter-Regular',Helvetica] font-normal text-[#fbffdb] text-xs tracking-[0] leading-[normal]"
                  >
                    Height (cm)
                  </label>

                  <input
                    id="height"
                    type="number"
                    value={formData.height}
                    onChange={e => handleInputChange('height', e.target.value)}
                    className="flex h-12 items-center justify-center gap-2.5 px-4 py-[11px] relative self-stretch w-full rounded-lg overflow-hidden border border-solid border-[#454545] [font-family:'Inter-Regular',Helvetica] font-normal text-[#595959] text-sm tracking-[0] leading-[normal] focus:border-[#ccd853] focus:outline-none"
                  />
                </div>
              </div>

              <div className="flex items-center gap-3.5 relative self-stretch w-full flex-[0_0_auto]">
                <div className="flex flex-col items-start gap-[9px] relative flex-1 grow">
                  <label
                    htmlFor="currentWeight"
                    className="relative self-stretch mt-[-1.00px] [font-family:'Inter-Regular',Helvetica] font-normal text-[#fbffdb] text-xs tracking-[0] leading-[normal]"
                  >
                    Current Weight (kg)
                  </label>

                  <input
                    id="currentWeight"
                    type="number"
                    value={formData.currentWeight}
                    onChange={e => handleInputChange('currentWeight', e.target.value)}
                    className="flex h-12 items-center justify-center gap-2.5 px-4 py-[11px] relative self-stretch w-full rounded-lg overflow-hidden border border-solid border-[#454545] [font-family:'Inter-Regular',Helvetica] font-normal text-[#595959] text-sm tracking-[0] leading-[normal] focus:border-[#ccd853] focus:outline-none"
                  />
                </div>

                <div className="flex flex-col items-start gap-[9px] relative flex-1 grow">
                  <label
                    htmlFor="targetWeight"
                    className="relative self-stretch mt-[-1.00px] [font-family:'Inter-Regular',Helvetica] font-normal text-[#fbffdb] text-xs tracking-[0] leading-[normal]"
                  >
                    Target Weight (kg)
                  </label>

                  <input
                    id="targetWeight"
                    type="number"
                    value={formData.targetWeight}
                    onChange={e => handleInputChange('targetWeight', e.target.value)}
                    className="flex h-12 items-center justify-center gap-2.5 px-4 py-[11px] relative self-stretch w-full rounded-lg overflow-hidden border border-solid border-[#454545] [font-family:'Inter-Regular',Helvetica] font-normal text-[#595959] text-sm tracking-[0] leading-[normal] focus:border-[#ccd853] focus:outline-none"
                  />
                </div>
              </div>

              <div className="flex flex-col items-start gap-[9px] relative self-stretch w-full flex-[0_0_auto]">
                <label
                  htmlFor="timeline"
                  className="relative self-stretch mt-[-1.00px] [font-family:'Inter-Regular',Helvetica] font-normal text-[#fbffdb] text-xs tracking-[0] leading-[normal]"
                >
                  Target Timeline
                </label>

                <div className="flex items-start gap-[9px] relative self-stretch w-full flex-[0_0_auto]">
                  <input
                    id="timeline"
                    type="number"
                    value={formData.timeline}
                    onChange={e => handleInputChange('timeline', e.target.value)}
                    className="flex h-12 items-center justify-center gap-2.5 px-4 py-[11px] relative flex-1 grow rounded-lg overflow-hidden border border-solid border-[#454545] [font-family:'Inter-Regular',Helvetica] font-normal text-[#595959] text-sm tracking-[0] leading-[normal] focus:border-[#ccd853] focus:outline-none"
                  />

                  <div
                    className="inline-flex flex-[0_0_auto] items-center relative"
                    role="group"
                    aria-label="Timeline unit selector"
                  >
                    <button
                      type="button"
                      onClick={() => handleTimelineUnitChange('weeks')}
                      className={`flex w-[83px] h-12 items-center justify-center gap-2.5 px-4 py-[11px] relative rounded-[8px_0px_0px_8px] overflow-hidden ${
                        formData.timelineUnit === 'weeks' ? 'bg-[#0088ff]' : 'bg-[#212121]'
                      }`}
                      aria-pressed={formData.timelineUnit === 'weeks'}
                    >
                      <span className="relative w-fit [font-family:'Inter-SemiBold',Helvetica] font-semibold text-[#e4e4e4] text-sm tracking-[0] leading-[normal]">
                        Weeks
                      </span>
                    </button>

                    <button
                      type="button"
                      onClick={() => handleTimelineUnitChange('months')}
                      className={`flex w-[83px] h-12 items-center justify-center gap-2.5 px-4 py-[11px] relative rounded-[0px_8px_8px_0px] overflow-hidden ${
                        formData.timelineUnit === 'months' ? 'bg-[#0088ff]' : 'bg-[#212121]'
                      }`}
                      aria-pressed={formData.timelineUnit === 'months'}
                    >
                      <span className="relative w-fit ml-[-0.50px] mr-[-0.50px] [font-family:'Inter-SemiBold',Helvetica] font-semibold text-[#e4e4e4] text-sm tracking-[0] leading-[normal]">
                        Months
                      </span>
                    </button>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <p className="relative self-stretch [font-family:'Inter-Medium',Helvetica] font-medium text-[#999999] text-xs tracking-[0.24px] leading-[16.8px]">
            This helps us calculate accurate calorie &amp; workout targets.
          </p>
        </div>

        <button
          type="button"
          onClick={handleContinue}
          className="flex h-12 justify-center gap-1 px-4 py-2 self-stretch w-full bg-[#ccd853] rounded-[30px] items-center relative cursor-pointer hover:bg-[#d4e05f] transition-colors"
        >
          <span className="relative w-fit [font-family:'Inter-SemiBold',Helvetica] font-semibold text-[#1e1e1e] text-sm tracking-[0] leading-[normal]">
            Continue
          </span>
        </button>
      </form>
    </div>
  );
};
