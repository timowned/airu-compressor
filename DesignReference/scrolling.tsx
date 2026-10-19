const assetPathPrefix = "https://www.figma.com/api/mcp/asset/80225360-3852-42f2-82b5-a9f6bbd40e41";
const imgFolder = `${assetPathPrefix}/be026.png`;
const imgFrame34 = `${assetPathPrefix}/d3751.png`;
const imgVector = `${assetPathPrefix}/beeb3.svg`;
const imgVector1 = `${assetPathPrefix}/feec3.svg`;

type WindowControlsStandardProps = {
  className?: string;
  active?: "True";
  mode?: "Dark";
};

function WindowControlsStandard({ className, active = "True", mode = "Dark" }: WindowControlsStandardProps) {
  return (
    <div className={className || "content-stretch flex gap-[9px] items-center pointer-events-none pr-[8px] relative"} data-node-id="4002:1396">
      <div className="relative rounded-[100px] shrink-0 size-[14px]" data-node-id="4002:1397" data-name="Close">
        <div aria-hidden className="absolute bg-[#f06e6a] inset-0 rounded-[100px]" />
        <div className="absolute inset-0 rounded-[inherit] shadow-[inset_0px_1.25px_0.5px_-0.75px_#999,inset_0px_-1.25px_0.5px_-0.75px_#808080,inset_0px_5px_4px_-3px_#262626,inset_0px_0px_3px_0px_rgba(153,31,0,0.6),inset_0px_17px_4px_-10px_rgba(153,31,0,0.4)]" />
      </div>
      <div className="relative rounded-[100px] shrink-0 size-[14px]" data-node-id="4002:1398" data-name="Minimize">
        <div aria-hidden className="absolute bg-[#ffcd30] inset-0 rounded-[100px]" />
        <div className="absolute inset-0 rounded-[inherit] shadow-[inset_0px_1.25px_0.5px_-0.75px_#999,inset_0px_-1.25px_0.5px_-0.75px_#808080,inset_0px_5px_4px_-3px_#161616,inset_0px_0px_3px_0px_#4d2e0f,inset_0px_17px_4px_-10px_#4d2e0f]" />
      </div>
      <div className="relative rounded-[100px] shrink-0 size-[14px]" data-node-id="4002:1399" data-name="Zoom">
        <div aria-hidden className="absolute bg-[#58c73b] inset-0 rounded-[100px]" />
        <div className="absolute inset-0 rounded-[inherit] shadow-[inset_0px_1.25px_0.5px_-0.75px_#999,inset_0px_-1.25px_0.5px_-0.75px_#808080,inset_0px_5px_4px_-3px_#262626,inset_0px_0px_3px_0px_rgba(17,51,0,0.8),inset_0px_17px_4px_-10px_rgba(17,51,0,0.6)]" />
      </div>
    </div>
  );
}

export default function Scrolling() {
  return (
    <div className="bg-[#151515] content-stretch flex flex-col items-center overflow-clip relative rounded-[22px] size-full" data-node-id="4012:4829" data-name="Scrolling">
      <div className="content-stretch flex flex-col gap-[10px] items-start p-[22px] relative shrink-0 w-full" data-node-id="4012:4830">
        <WindowControlsStandard className="content-stretch flex gap-[9px] items-center pointer-events-none pr-[8px] relative shrink-0" />
        <div className="-translate-x-1/2 absolute bg-[rgba(255,255,255,0.05)] content-stretch flex items-center left-1/2 p-[4px] rounded-[67px] top-[14px]" data-node-id="4012:4832">
          <div className="bg-[rgba(0,0,0,0.3)] content-stretch flex items-center justify-center px-[12px] py-[11px] relative rounded-[39px] shrink-0" data-node-id="4012:4833">
            <div className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] [word-break:break-word] flex flex-col font-['SF_Pro:Regular'] font-normal justify-center leading-[0] relative shrink-0 text-[14px] text-center text-white whitespace-nowrap" data-node-id="4012:4834" style={{ fontVariationSettings: '"wdth" 100' }}>
              <p className="leading-[16px]">Auto</p>
            </div>
          </div>
          <div className="content-stretch flex items-center justify-center px-[12px] py-[11px] relative rounded-[39px] shrink-0" data-node-id="4012:4835">
            <div className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] [word-break:break-word] flex flex-col font-['SF_Pro:Regular'] font-normal justify-center leading-[0] relative shrink-0 text-[14px] text-center text-white whitespace-nowrap" data-node-id="4012:4836" style={{ fontVariationSettings: '"wdth" 100' }}>
              <p className="leading-[16px]">Manual</p>
            </div>
          </div>
        </div>
      </div>
      <div className="content-stretch flex flex-[1_0_0] flex-col items-center justify-center min-h-px p-[20px] relative w-full" data-node-id="4012:4837">
        <div className="content-stretch flex flex-[1_0_0] flex-col items-center justify-between min-h-px overflow-clip relative w-full" data-node-id="4012:4838">
          <div className="content-stretch flex flex-col h-[409px] items-start relative shrink-0 w-full" data-node-id="4012:4839">
            <div className="absolute bg-white h-px left-0 opacity-10 top-[-24px] w-[600px]" data-node-id="4012:4840" />
            <div className="absolute content-stretch flex items-center justify-between left-0 py-[20px] top-[-23px] w-[600px]" data-node-id="4012:4841">
              <div className="content-stretch flex items-center justify-center relative shrink-0" data-node-id="4012:4842">
                <div className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] [word-break:break-word] flex flex-col font-['SF_Pro:Light'] font-[274.31500244140625] justify-center leading-[0] relative shrink-0 text-[13px] text-center text-white whitespace-nowrap" data-node-id="4012:4843" style={{ fontVariationSettings: '"wdth" 100' }}>
                  <p className="leading-[16px]">[File name]</p>
                </div>
              </div>
              <div className="content-stretch flex items-center relative shrink-0" data-node-id="4012:4844">
                <div className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] [word-break:break-word] flex flex-col font-['SF_Pro:Light'] font-[274.31500244140625] justify-center leading-[0] relative shrink-0 text-[13px] text-center text-white whitespace-nowrap" data-node-id="4012:4845" style={{ fontVariationSettings: '"wdth" 100' }}>
                  <p className="leading-[16px]">2.2MB</p>
                </div>
              </div>
            </div>
            <div className="absolute bg-white h-px left-0 opacity-10 top-[26px] w-[600px]" data-node-id="4012:4846" />
            <div className="absolute content-stretch flex items-center justify-between left-0 py-[20px] top-[27px] w-[600px]" data-node-id="4012:4847">
              <div className="content-stretch flex items-center justify-center relative shrink-0" data-node-id="4012:4848">
                <div className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] [word-break:break-word] flex flex-col font-['SF_Pro:Light'] font-[274.31500244140625] justify-center leading-[0] relative shrink-0 text-[13px] text-center text-white whitespace-nowrap" data-node-id="4012:4849" style={{ fontVariationSettings: '"wdth" 100' }}>
                  <p className="leading-[16px]">[File name]</p>
                </div>
              </div>
              <div className="content-stretch flex items-center relative shrink-0" data-node-id="4012:4850">
                <div className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] [word-break:break-word] flex flex-col font-['SF_Pro:Light'] font-[274.31500244140625] justify-center leading-[0] relative shrink-0 text-[13px] text-center text-white whitespace-nowrap" data-node-id="4012:4851" style={{ fontVariationSettings: '"wdth" 100' }}>
                  <p className="leading-[16px]">2.2MB</p>
                </div>
              </div>
            </div>
            <div className="absolute bg-white h-px left-0 opacity-10 top-[76px] w-[600px]" data-node-id="4012:4852" />
            <div className="absolute content-stretch flex h-[51px] items-center justify-between left-0 py-[20px] top-[77px] w-[600px]" data-node-id="4012:4853">
              <div className="content-stretch flex items-center justify-center relative shrink-0" data-node-id="4012:4854">
                <div className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] [word-break:break-word] flex flex-col font-['SF_Pro:Light'] font-[274.31500244140625] justify-center leading-[0] relative shrink-0 text-[13px] text-center text-white whitespace-nowrap" data-node-id="4012:4855" style={{ fontVariationSettings: '"wdth" 100' }}>
                  <p className="leading-[16px]">[File name]</p>
                </div>
              </div>
              <div className="content-stretch flex items-center relative shrink-0" data-node-id="4012:4856">
                <div className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] [word-break:break-word] flex flex-col font-['SF_Pro:Light'] font-[274.31500244140625] justify-center leading-[0] relative shrink-0 text-[13px] text-center text-white whitespace-nowrap" data-node-id="4012:4857" style={{ fontVariationSettings: '"wdth" 100' }}>
                  <p className="leading-[16px]">2.2MB</p>
                </div>
              </div>
            </div>
            <div className="absolute bg-white h-px left-0 opacity-10 top-[128px] w-[600px]" data-node-id="4012:4858" />
            <div className="absolute content-stretch flex h-[51px] items-center justify-between left-0 py-[20px] top-[129px] w-[600px]" data-node-id="4012:4859">
              <div className="content-stretch flex items-center justify-center relative shrink-0" data-node-id="4012:4860">
                <div className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] [word-break:break-word] flex flex-col font-['SF_Pro:Light'] font-[274.31500244140625] justify-center leading-[0] relative shrink-0 text-[13px] text-center text-white whitespace-nowrap" data-node-id="4012:4861" style={{ fontVariationSettings: '"wdth" 100' }}>
                  <p className="leading-[16px]">[File name]</p>
                </div>
              </div>
              <div className="content-stretch flex items-center relative shrink-0" data-node-id="4012:4862">
                <div className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] [word-break:break-word] flex flex-col font-['SF_Pro:Light'] font-[274.31500244140625] justify-center leading-[0] relative shrink-0 text-[13px] text-center text-white whitespace-nowrap" data-node-id="4012:4863" style={{ fontVariationSettings: '"wdth" 100' }}>
                  <p className="leading-[16px]">2.2MB</p>
                </div>
              </div>
            </div>
            <div className="absolute bg-white h-px left-0 opacity-10 top-[180px] w-[600px]" data-node-id="4012:4864" />
            <div className="absolute content-stretch flex items-center justify-between left-0 py-[20px] top-[181px] w-[600px]" data-node-id="4012:4951">
              <div className="content-stretch flex items-center justify-center relative shrink-0" data-node-id="4012:4952">
                <div className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] [word-break:break-word] flex flex-col font-['SF_Pro:Light'] font-[274.31500244140625] justify-center leading-[0] relative shrink-0 text-[13px] text-center text-white whitespace-nowrap" data-node-id="4012:4953" style={{ fontVariationSettings: '"wdth" 100' }}>
                  <p className="leading-[16px]">[File name]</p>
                </div>
              </div>
              <div className="content-stretch flex items-center relative shrink-0" data-node-id="4012:4954">
                <div className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] [word-break:break-word] flex flex-col font-['SF_Pro:Light'] font-[274.31500244140625] justify-center leading-[0] relative shrink-0 text-[13px] text-center text-white whitespace-nowrap" data-node-id="4012:4955" style={{ fontVariationSettings: '"wdth" 100' }}>
                  <p className="leading-[16px]">2.2MB</p>
                </div>
              </div>
            </div>
            <div className="absolute bg-white h-px left-0 opacity-10 top-[230px] w-[600px]" data-node-id="4012:4956" />
            <div className="absolute content-stretch flex items-center justify-between left-0 py-[20px] top-[231px] w-[600px]" data-node-id="4012:4957">
              <div className="content-stretch flex items-center justify-center relative shrink-0" data-node-id="4012:4958">
                <div className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] [word-break:break-word] flex flex-col font-['SF_Pro:Light'] font-[274.31500244140625] justify-center leading-[0] relative shrink-0 text-[13px] text-center text-white whitespace-nowrap" data-node-id="4012:4959" style={{ fontVariationSettings: '"wdth" 100' }}>
                  <p className="leading-[16px]">[File name]</p>
                </div>
              </div>
              <div className="content-stretch flex items-center relative shrink-0" data-node-id="4012:4960">
                <div className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] [word-break:break-word] flex flex-col font-['SF_Pro:Light'] font-[274.31500244140625] justify-center leading-[0] relative shrink-0 text-[13px] text-center text-white whitespace-nowrap" data-node-id="4012:4961" style={{ fontVariationSettings: '"wdth" 100' }}>
                  <p className="leading-[16px]">2.2MB</p>
                </div>
              </div>
            </div>
            <div className="absolute bg-white h-px left-0 opacity-10 top-[280px] w-[600px]" data-node-id="4012:4962" />
            <div className="absolute content-stretch flex h-[51px] items-center justify-between left-0 py-[20px] top-[281px] w-[600px]" data-node-id="4012:4963">
              <div className="content-stretch flex items-center justify-center relative shrink-0" data-node-id="4012:4964">
                <div className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] [word-break:break-word] flex flex-col font-['SF_Pro:Light'] font-[274.31500244140625] justify-center leading-[0] relative shrink-0 text-[13px] text-center text-white whitespace-nowrap" data-node-id="4012:4965" style={{ fontVariationSettings: '"wdth" 100' }}>
                  <p className="leading-[16px]">[File name]</p>
                </div>
              </div>
              <div className="content-stretch flex items-center relative shrink-0" data-node-id="4012:4966">
                <div className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] [word-break:break-word] flex flex-col font-['SF_Pro:Light'] font-[274.31500244140625] justify-center leading-[0] relative shrink-0 text-[13px] text-center text-white whitespace-nowrap" data-node-id="4012:4967" style={{ fontVariationSettings: '"wdth" 100' }}>
                  <p className="leading-[16px]">2.2MB</p>
                </div>
              </div>
            </div>
            <div className="absolute bg-white h-px left-0 opacity-10 top-[332px] w-[600px]" data-node-id="4012:4968" />
            <div className="absolute content-stretch flex h-[51px] items-center justify-between left-0 py-[20px] top-[333px] w-[600px]" data-node-id="4012:4969">
              <div className="content-stretch flex items-center justify-center relative shrink-0" data-node-id="4012:4970">
                <div className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] [word-break:break-word] flex flex-col font-['SF_Pro:Light'] font-[274.31500244140625] justify-center leading-[0] relative shrink-0 text-[13px] text-center text-white whitespace-nowrap" data-node-id="4012:4971" style={{ fontVariationSettings: '"wdth" 100' }}>
                  <p className="leading-[16px]">[File name]</p>
                </div>
              </div>
              <div className="content-stretch flex items-center relative shrink-0" data-node-id="4012:4972">
                <div className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] [word-break:break-word] flex flex-col font-['SF_Pro:Light'] font-[274.31500244140625] justify-center leading-[0] relative shrink-0 text-[13px] text-center text-white whitespace-nowrap" data-node-id="4012:4973" style={{ fontVariationSettings: '"wdth" 100' }}>
                  <p className="leading-[16px]">2.2MB</p>
                </div>
              </div>
            </div>
            <div className="absolute bg-white h-px left-0 opacity-10 top-[384px] w-[600px]" data-node-id="4012:4974" />
          </div>
        </div>
      </div>
      <div className="-translate-x-1/2 absolute bg-[rgba(255,255,255,0.05)] content-stretch flex items-center justify-center left-[calc(50%+280px)] p-[5px] rounded-[67px] size-[40px] top-[14px]" data-node-id="4012:4891">
        <div className="grid-cols-[max-content] grid-rows-[max-content] inline-grid leading-[0] place-items-start relative shrink-0" data-node-id="4012:4892">
          <div className="bg-[#afafaf] col-1 h-[16px] ml-[7px] mt-0 relative row-1 w-[1.6px]" data-node-id="4012:4893" />
          <div className="col-1 flex h-[1.6px] items-center justify-center ml-0 mt-[7px] relative row-1 w-[16px]" data-node-id="4012:4894">
            <div className="flex-none rotate-90">
              <div className="bg-[#afafaf] h-[16px] relative w-[1.6px]" />
            </div>
          </div>
        </div>
      </div>
      <div className="-translate-x-1/2 absolute bg-[#151515] content-stretch flex items-end justify-between left-1/2 top-[353px] w-[600px]" data-node-id="4012:4979">
        <div className="content-stretch flex flex-col gap-[10px] items-start relative shrink-0" data-node-id="4012:4980">
          <div className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] [word-break:break-word] flex flex-col font-['SF_Pro:Regular'] font-normal justify-center leading-[0] relative shrink-0 text-[13px] text-[rgba(255,255,255,0.8)] text-center whitespace-nowrap" data-node-id="4012:4981" style={{ fontVariationSettings: '"wdth" 100' }}>
            <p className="leading-[16px]">Compress to</p>
          </div>
          <div className="bg-[#131313] content-stretch flex flex-col items-start p-px relative rounded-[10px] shrink-0" data-node-id="4012:4982">
            <div className="bg-[#1e1e1e] border border-[#272727] border-solid content-stretch flex gap-[10px] h-[36px] items-center justify-center overflow-clip pl-[10px] pr-[2px] relative rounded-[9px] shrink-0 w-full" data-node-id="4012:4983">
              <div className="[word-break:break-word] content-stretch flex gap-[6px] items-center leading-[16px] relative shrink-0 text-[13px] text-white whitespace-nowrap" data-node-id="4012:4984">
                <p className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] font-['SF_Pro:Medium'] font-[510] overflow-hidden relative shrink-0 text-ellipsis" data-node-id="4012:4985" style={{ fontVariationSettings: '"wdth" 100' }}>
                  JPEG
                </p>
                <p className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] font-['SF_Pro:Light'] font-[274.31500244140625] opacity-50 overflow-hidden relative shrink-0 text-ellipsis" data-node-id="4012:4986" style={{ fontVariationSettings: '"wdth" 100' }}>
                  Airy
                </p>
              </div>
              <div className="overflow-clip relative rounded-[6.5px] shrink-0 size-[30px]" data-node-id="4012:4987" data-name="Combo Box Button">
                <div className="absolute bg-[rgba(255,255,255,0.08)] inset-0" data-node-id="4012:4988" data-name="Button BG" />
                <div className="[word-break:break-word] absolute flex flex-col font-['SF_Pro:Bold'] font-bold inset-0 justify-center leading-[0] text-[length:var(--combo-button\/font-size---chevron,11px)] text-center text-white" data-node-id="4012:4989" style={{ fontVariationSettings: '"wdth" 100', fontFeatureSettings: '"ss15" 1' }}>
                  <SFSymbol>{`Image(systemName: "chevron.down")`}</SFSymbol>
                </div>
              </div>
            </div>
          </div>
        </div>
        <div className="content-stretch flex gap-[12px] items-center relative shrink-0" data-node-id="4012:4990">
          <div className="bg-[#131313] content-stretch flex flex-col items-start p-px relative rounded-[10px] shrink-0" data-node-id="4012:4991">
            <div className="bg-[#1e1e1e] border border-[#272727] border-solid content-stretch flex h-[36px] items-center justify-center overflow-clip px-[11px] relative rounded-[9px] shrink-0 w-full" data-node-id="4012:4992">
              <div className="h-[10.757px] relative shrink-0 w-[14px]" data-node-id="4012:4993" data-name="Vector">
                <img alt="" className="absolute block inset-0 max-w-none size-full" src={imgVector} />
              </div>
            </div>
          </div>
          <div className="content-stretch flex gap-[10px] h-[36px] items-center relative rounded-[67px] shrink-0" data-node-id="4012:4994">
            <div className="content-stretch flex gap-[4px] items-center justify-center relative rounded-[39px] shrink-0" data-node-id="4012:4995">
              <div className="content-stretch flex items-center p-[1.778px] relative shrink-0" data-node-id="4012:4996" data-name="Icon">
                <div className="relative shrink-0 size-[12.444px]" data-node-id="I4012:4996;4356:10693" data-name="Folder">
                  <img alt="" className="absolute inset-0 max-w-none object-cover pointer-events-none size-full" src={imgFolder} />
                </div>
              </div>
              <div className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] [word-break:break-word] flex flex-col font-['SF_Pro:Regular'] font-normal justify-center leading-[0] relative shrink-0 text-[12px] text-center text-white whitespace-nowrap" data-node-id="4012:4997" style={{ fontVariationSettings: '"wdth" 100' }}>
                <p className="leading-[16px]">timparanitsa</p>
              </div>
            </div>
            <div className="h-[8px] relative shrink-0 w-[4px]" data-node-id="4012:4998">
              <div className="absolute inset-[-4.42%_-17.68%_-4.42%_-8.84%]">
                <img alt="" className="block max-w-none size-full" src={imgVector1} />
              </div>
            </div>
            <div className="content-stretch flex gap-[4px] items-center justify-center relative rounded-[39px] shrink-0" data-node-id="4012:4999">
              <div className="content-stretch flex items-center p-[1.778px] relative shrink-0" data-node-id="4012:5000" data-name="Icon">
                <div className="relative shrink-0 size-[12.444px]" data-node-id="I4012:5000;4356:10693" data-name="Folder">
                  <img alt="" className="absolute inset-0 max-w-none object-cover pointer-events-none size-full" src={imgFolder} />
                </div>
              </div>
              <div className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] [word-break:break-word] flex flex-col font-['SF_Pro:Regular'] font-normal justify-center leading-[0] relative shrink-0 text-[12px] text-center text-white whitespace-nowrap" data-node-id="4012:5001" style={{ fontVariationSettings: '"wdth" 100' }}>
                <p className="leading-[16px]">Desktop</p>
              </div>
            </div>
          </div>
        </div>
        <div className="bg-[#666] content-stretch flex flex-col items-start p-px relative rounded-[10px] shrink-0" data-node-id="4012:5002">
          <div className="bg-[#ededed] border border-[#131313] border-solid content-stretch flex h-[36px] items-center justify-center overflow-clip px-[10px] relative rounded-[9px] shrink-0 w-full" data-node-id="4012:5003">
            <p className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] [word-break:break-word] font-['SF_Pro:Medium'] font-[510] leading-[16px] overflow-hidden relative shrink-0 text-[13px] text-black text-ellipsis whitespace-nowrap" data-node-id="4012:5004" style={{ fontVariationSettings: '"wdth" 100' }}>
              Airufy
            </p>
          </div>
        </div>
      </div>
      <div className="-translate-x-1/2 absolute h-[37px] left-1/2 top-[78px] w-[606px]" data-node-id="4012:5009">
        <img alt="" className="absolute inset-0 max-w-none object-cover pointer-events-none size-full" src={imgFrame34} />
      </div>
      <div className="-translate-x-1/2 absolute flex h-[37px] items-center justify-center left-1/2 top-[306px] w-[606px]" data-node-id="4012:5011">
        <div className="-scale-y-100 flex-none">
          <div className="h-[37px] relative w-[606px]">
            <img alt="" className="absolute inset-0 max-w-none object-cover pointer-events-none size-full" src={imgFrame34} />
          </div>
        </div>
      </div>
      <div className="absolute bg-[#8b8b8b] h-[143px] left-[628.5px] rounded-[32px] top-[73px] w-[5px]" data-node-id="4012:5046" />
    </div>
  );
}
SUPER CRITICAL: The generated React+Tailwind code MUST be converted to match the target project's technology stack and styling system.
1. Analyze the target codebase to identify: technology stack, styling approach, component patterns, and design tokens
2. Convert React syntax to the target framework/library
3. Transform all Tailwind classes to the target styling system while preserving exact visual design
4. Follow the project's existing patterns and conventions
DO NOT install any Tailwind as a dependency unless the user instructs you to do so.

Node ids have been added to the code as data attributes, e.g. `data-node-id="1:2"`.
The generated code contains image and SVG URL constants, e.g. const image = `${assetPathPrefix}/<asset file name>`, where assetPathPrefix is declared once at the top of the code and every asset URL interpolates it. These URLs are temporary download sources and expire after 7 days. Download each asset into the project with curl -L, then replace its URL in the generated code with a reference to the downloaded asset. Never use the temporary URLs as runtime image sources.