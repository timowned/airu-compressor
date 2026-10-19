const assetPathPrefix = "https://www.figma.com/api/mcp/asset/a146da9f-92e9-4128-9926-de6e4fccf529";
const imgFolder = `${assetPathPrefix}/be026.png`;
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

export default function AllCompressed() {
  return (
    <div className="bg-[#151515] content-stretch flex flex-col items-center overflow-clip relative rounded-[22px] size-full" data-node-id="4010:2604" data-name="All Compressed">
      <div className="content-stretch flex flex-col gap-[10px] items-start p-[22px] relative shrink-0 w-full" data-node-id="4010:2605">
        <WindowControlsStandard className="content-stretch flex gap-[9px] items-center pointer-events-none pr-[8px] relative shrink-0" />
        <div className="-translate-x-1/2 absolute bg-[rgba(255,255,255,0.05)] content-stretch flex items-center left-1/2 p-[4px] rounded-[67px] top-[14px]" data-node-id="4010:2607">
          <div className="bg-[rgba(0,0,0,0.3)] content-stretch flex items-center justify-center px-[12px] py-[11px] relative rounded-[39px] shrink-0" data-node-id="4010:2608">
            <div className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] [word-break:break-word] flex flex-col font-['SF_Pro:Regular'] font-normal justify-center leading-[0] relative shrink-0 text-[14px] text-center text-white whitespace-nowrap" data-node-id="4010:2609" style={{ fontVariationSettings: '"wdth" 100' }}>
              <p className="leading-[16px]">Auto</p>
            </div>
          </div>
          <div className="content-stretch flex items-center justify-center px-[12px] py-[11px] relative rounded-[39px] shrink-0" data-node-id="4010:2610">
            <div className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] [word-break:break-word] flex flex-col font-['SF_Pro:Regular'] font-normal justify-center leading-[0] relative shrink-0 text-[14px] text-center text-white whitespace-nowrap" data-node-id="4010:2611" style={{ fontVariationSettings: '"wdth" 100' }}>
              <p className="leading-[16px]">Manual</p>
            </div>
          </div>
        </div>
      </div>
      <div className="content-stretch flex flex-[1_0_0] flex-col gap-[10px] items-center justify-center min-h-px p-[20px] relative w-full" data-node-id="4010:2612">
        <div className="content-stretch flex flex-[1_0_0] flex-col items-center justify-between min-h-px overflow-clip relative w-full" data-node-id="4010:2613">
          <div className="content-stretch flex flex-col items-start relative shrink-0 w-full" data-node-id="4010:2846">
            <div className="bg-white h-px opacity-10 relative shrink-0 w-full" data-node-id="4010:2847" />
            <div className="content-stretch flex items-center justify-between py-[20px] relative shrink-0 w-full" data-node-id="4010:2848">
              <div className="content-stretch flex items-center justify-center relative shrink-0" data-node-id="4010:2849">
                <div className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] [word-break:break-word] flex flex-col font-['SF_Pro:Light'] font-[274.31500244140625] justify-center leading-[0] relative shrink-0 text-[13px] text-center text-white whitespace-nowrap" data-node-id="4010:2850" style={{ fontVariationSettings: '"wdth" 100' }}>
                  <p className="leading-[16px]">[File name]</p>
                </div>
              </div>
              <div className="[word-break:break-word] content-stretch flex gap-[5px] items-center leading-[0] relative shrink-0 text-center whitespace-nowrap" data-node-id="4010:2851">
                <div className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] flex flex-col font-['SF_Pro:Light'] font-[274.31500244140625] justify-center relative shrink-0 text-[13px] text-[rgba(255,255,255,0.5)]" data-node-id="4010:2852" style={{ fontVariationSettings: '"wdth" 100' }}>
                  <p className="leading-[16px]">2.2MB</p>
                </div>
                <div className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] flex flex-col font-['SF_Pro:Regular'] font-normal justify-center relative shrink-0 text-[14px] text-[rgba(255,255,255,0.5)]" data-node-id="4010:2853" style={{ fontVariationSettings: '"wdth" 100' }}>
                  <p className="leading-[16px]">→</p>
                </div>
                <div className="content-stretch flex font-['SF_Pro:Regular'] font-normal gap-[4px] items-end relative shrink-0" data-node-id="4010:2854">
                  <div className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] bg-clip-text bg-gradient-to-l flex flex-col from-[#24dc21] justify-center relative shrink-0 text-[13px] text-[transparent] to-[#91dc21]" data-node-id="4010:2855" style={{ fontVariationSettings: '"wdth" 100' }}>
                    <p className="leading-[16px]">1.2MB</p>
                  </div>
                  <div className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] flex flex-col justify-center opacity-66 relative shrink-0 text-[#37dc21] text-[10px]" data-node-id="4010:2856" style={{ fontVariationSettings: '"wdth" 100' }}>
                    <p className="leading-[16px]">(-40%)</p>
                  </div>
                </div>
              </div>
            </div>
            <div className="bg-white h-px opacity-10 relative shrink-0 w-full" data-node-id="4010:2857" />
            <div className="content-stretch flex items-center justify-between py-[20px] relative shrink-0 w-full" data-node-id="4010:2858">
              <div className="content-stretch flex items-center justify-center relative shrink-0" data-node-id="4010:2859">
                <div className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] [word-break:break-word] flex flex-col font-['SF_Pro:Light'] font-[274.31500244140625] justify-center leading-[0] relative shrink-0 text-[13px] text-center text-white whitespace-nowrap" data-node-id="4010:2860" style={{ fontVariationSettings: '"wdth" 100' }}>
                  <p className="leading-[16px]">[File name]</p>
                </div>
              </div>
              <div className="[word-break:break-word] content-stretch flex gap-[5px] items-center leading-[0] relative shrink-0 text-center whitespace-nowrap" data-node-id="4010:2861">
                <div className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] flex flex-col font-['SF_Pro:Light'] font-[274.31500244140625] justify-center relative shrink-0 text-[13px] text-[rgba(255,255,255,0.5)]" data-node-id="4010:2862" style={{ fontVariationSettings: '"wdth" 100' }}>
                  <p className="leading-[16px]">2.2MB</p>
                </div>
                <div className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] flex flex-col font-['SF_Pro:Regular'] font-normal justify-center relative shrink-0 text-[14px] text-[rgba(255,255,255,0.5)]" data-node-id="4010:2863" style={{ fontVariationSettings: '"wdth" 100' }}>
                  <p className="leading-[16px]">→</p>
                </div>
                <div className="content-stretch flex font-['SF_Pro:Regular'] font-normal gap-[4px] items-end relative shrink-0" data-node-id="4010:2864">
                  <div className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] bg-clip-text bg-gradient-to-l flex flex-col from-[#24dc21] justify-center relative shrink-0 text-[13px] text-[transparent] to-[#91dc21]" data-node-id="4010:2865" style={{ fontVariationSettings: '"wdth" 100' }}>
                    <p className="leading-[16px]">1.2MB</p>
                  </div>
                  <div className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] flex flex-col justify-center opacity-66 relative shrink-0 text-[#37dc21] text-[10px]" data-node-id="4010:2866" style={{ fontVariationSettings: '"wdth" 100' }}>
                    <p className="leading-[16px]">(-40%)</p>
                  </div>
                </div>
              </div>
            </div>
            <div className="bg-white h-px opacity-10 relative shrink-0 w-full" data-node-id="4010:2867" />
            <div className="content-stretch flex h-[51px] items-center justify-between py-[20px] relative shrink-0 w-full" data-node-id="4010:2868">
              <div className="content-stretch flex items-center justify-center relative shrink-0" data-node-id="4010:2869">
                <div className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] [word-break:break-word] flex flex-col font-['SF_Pro:Light'] font-[274.31500244140625] justify-center leading-[0] relative shrink-0 text-[13px] text-center text-white whitespace-nowrap" data-node-id="4010:2870" style={{ fontVariationSettings: '"wdth" 100' }}>
                  <p className="leading-[16px]">[File name]</p>
                </div>
              </div>
              <div className="[word-break:break-word] content-stretch flex gap-[5px] items-center leading-[0] relative shrink-0 text-center whitespace-nowrap" data-node-id="4010:2871">
                <div className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] flex flex-col font-['SF_Pro:Light'] font-[274.31500244140625] justify-center relative shrink-0 text-[13px] text-[rgba(255,255,255,0.5)]" data-node-id="4010:2872" style={{ fontVariationSettings: '"wdth" 100' }}>
                  <p className="leading-[16px]">2.2MB</p>
                </div>
                <div className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] flex flex-col font-['SF_Pro:Regular'] font-normal justify-center relative shrink-0 text-[14px] text-[rgba(255,255,255,0.5)]" data-node-id="4010:2873" style={{ fontVariationSettings: '"wdth" 100' }}>
                  <p className="leading-[16px]">→</p>
                </div>
                <div className="content-stretch flex font-['SF_Pro:Regular'] font-normal gap-[4px] items-end relative shrink-0" data-node-id="4010:2874">
                  <div className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] bg-clip-text bg-gradient-to-l flex flex-col from-[#24dc21] justify-center relative shrink-0 text-[13px] text-[transparent] to-[#91dc21]" data-node-id="4010:2875" style={{ fontVariationSettings: '"wdth" 100' }}>
                    <p className="leading-[16px]">1.2MB</p>
                  </div>
                  <div className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] flex flex-col justify-center opacity-66 relative shrink-0 text-[#37dc21] text-[10px]" data-node-id="4010:2876" style={{ fontVariationSettings: '"wdth" 100' }}>
                    <p className="leading-[16px]">(-40%)</p>
                  </div>
                </div>
              </div>
            </div>
            <div className="bg-white h-px opacity-10 relative shrink-0 w-full" data-node-id="4010:2877" />
            <div className="content-stretch flex h-[51px] items-center justify-between py-[20px] relative shrink-0 w-full" data-node-id="4010:2878">
              <div className="content-stretch flex items-center justify-center relative shrink-0" data-node-id="4010:2879">
                <div className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] [word-break:break-word] flex flex-col font-['SF_Pro:Light'] font-[274.31500244140625] justify-center leading-[0] relative shrink-0 text-[13px] text-center text-white whitespace-nowrap" data-node-id="4010:2880" style={{ fontVariationSettings: '"wdth" 100' }}>
                  <p className="leading-[16px]">[File name]</p>
                </div>
              </div>
              <div className="[word-break:break-word] content-stretch flex gap-[5px] items-center leading-[0] relative shrink-0 text-center whitespace-nowrap" data-node-id="4010:2881">
                <div className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] flex flex-col font-['SF_Pro:Light'] font-[274.31500244140625] justify-center relative shrink-0 text-[13px] text-[rgba(255,255,255,0.5)]" data-node-id="4010:2882" style={{ fontVariationSettings: '"wdth" 100' }}>
                  <p className="leading-[16px]">2.2MB</p>
                </div>
                <div className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] flex flex-col font-['SF_Pro:Regular'] font-normal justify-center relative shrink-0 text-[14px] text-[rgba(255,255,255,0.5)]" data-node-id="4010:2883" style={{ fontVariationSettings: '"wdth" 100' }}>
                  <p className="leading-[16px]">→</p>
                </div>
                <div className="content-stretch flex font-['SF_Pro:Regular'] font-normal gap-[4px] items-end relative shrink-0" data-node-id="4010:2884">
                  <div className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] bg-clip-text bg-gradient-to-l flex flex-col from-[#24dc21] justify-center relative shrink-0 text-[13px] text-[transparent] to-[#91dc21]" data-node-id="4010:2885" style={{ fontVariationSettings: '"wdth" 100' }}>
                    <p className="leading-[16px]">1.2MB</p>
                  </div>
                  <div className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] flex flex-col justify-center opacity-66 relative shrink-0 text-[#37dc21] text-[10px]" data-node-id="4010:2886" style={{ fontVariationSettings: '"wdth" 100' }}>
                    <p className="leading-[16px]">(-40%)</p>
                  </div>
                </div>
              </div>
            </div>
            <div className="bg-white h-px opacity-10 relative shrink-0 w-full" data-node-id="4010:2887" />
          </div>
        </div>
        <div className="content-stretch flex items-end justify-between relative shrink-0 w-full" data-node-id="4012:4771">
          <div className="content-stretch flex flex-col gap-[10px] items-start relative shrink-0" data-node-id="4012:4772">
            <div className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] [word-break:break-word] flex flex-col font-['SF_Pro:Regular'] font-normal justify-center leading-[0] relative shrink-0 text-[13px] text-[rgba(255,255,255,0.8)] text-center whitespace-nowrap" data-node-id="4012:4773" style={{ fontVariationSettings: '"wdth" 100' }}>
              <p className="leading-[16px]">Compress to</p>
            </div>
            <div className="bg-[#131313] content-stretch flex flex-col items-start p-px relative rounded-[10px] shrink-0" data-node-id="4012:4774">
              <div className="bg-[#1e1e1e] border border-[#272727] border-solid content-stretch flex gap-[10px] h-[36px] items-center justify-center overflow-clip pl-[10px] pr-[2px] relative rounded-[9px] shrink-0 w-full" data-node-id="4012:4775">
                <div className="[word-break:break-word] content-stretch flex gap-[6px] items-center leading-[16px] relative shrink-0 text-[13px] text-white whitespace-nowrap" data-node-id="4012:4776">
                  <p className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] font-['SF_Pro:Medium'] font-[510] overflow-hidden relative shrink-0 text-ellipsis" data-node-id="4012:4777" style={{ fontVariationSettings: '"wdth" 100' }}>
                    JPEG
                  </p>
                  <p className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] font-['SF_Pro:Light'] font-[274.31500244140625] opacity-50 overflow-hidden relative shrink-0 text-ellipsis" data-node-id="4012:4778" style={{ fontVariationSettings: '"wdth" 100' }}>
                    Airy
                  </p>
                </div>
                <div className="overflow-clip relative rounded-[6.5px] shrink-0 size-[30px]" data-node-id="4012:4779" data-name="Combo Box Button">
                  <div className="absolute bg-[rgba(255,255,255,0.08)] inset-0" data-node-id="4012:4780" data-name="Button BG" />
                  <div className="[word-break:break-word] absolute flex flex-col font-['SF_Pro:Bold'] font-bold inset-0 justify-center leading-[0] text-[length:var(--combo-button\/font-size---chevron,11px)] text-center text-white" data-node-id="4012:4781" style={{ fontVariationSettings: '"wdth" 100', fontFeatureSettings: '"ss15" 1' }}>
                    <SFSymbol>{`Image(systemName: "chevron.down")`}</SFSymbol>
                  </div>
                </div>
              </div>
            </div>
          </div>
          <div className="content-stretch flex gap-[12px] items-center relative shrink-0" data-node-id="4012:4782">
            <div className="bg-[#131313] content-stretch flex flex-col items-start p-px relative rounded-[10px] shrink-0" data-node-id="4012:4783">
              <div className="bg-[#1e1e1e] border border-[#272727] border-solid content-stretch flex h-[36px] items-center justify-center overflow-clip px-[11px] relative rounded-[9px] shrink-0 w-full" data-node-id="4012:4784">
                <div className="h-[10.757px] relative shrink-0 w-[14px]" data-node-id="4012:4785" data-name="Vector">
                  <img alt="" className="absolute block inset-0 max-w-none size-full" src={imgVector} />
                </div>
              </div>
            </div>
            <div className="content-stretch flex gap-[10px] h-[36px] items-center relative rounded-[67px] shrink-0" data-node-id="4012:4786">
              <div className="content-stretch flex gap-[4px] items-center justify-center relative rounded-[39px] shrink-0" data-node-id="4012:4787">
                <div className="content-stretch flex items-center p-[1.778px] relative shrink-0" data-node-id="4012:4788" data-name="Icon">
                  <div className="relative shrink-0 size-[12.444px]" data-node-id="I4012:4788;4356:10693" data-name="Folder">
                    <img alt="" className="absolute inset-0 max-w-none object-cover pointer-events-none size-full" src={imgFolder} />
                  </div>
                </div>
                <div className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] [word-break:break-word] flex flex-col font-['SF_Pro:Regular'] font-normal justify-center leading-[0] relative shrink-0 text-[12px] text-center text-white whitespace-nowrap" data-node-id="4012:4789" style={{ fontVariationSettings: '"wdth" 100' }}>
                  <p className="leading-[16px]">timparanitsa</p>
                </div>
              </div>
              <div className="h-[8px] relative shrink-0 w-[4px]" data-node-id="4012:4790">
                <div className="absolute inset-[-4.42%_-17.68%_-4.42%_-8.84%]">
                  <img alt="" className="block max-w-none size-full" src={imgVector1} />
                </div>
              </div>
              <div className="content-stretch flex gap-[4px] items-center justify-center relative rounded-[39px] shrink-0" data-node-id="4012:4791">
                <div className="content-stretch flex items-center p-[1.778px] relative shrink-0" data-node-id="4012:4792" data-name="Icon">
                  <div className="relative shrink-0 size-[12.444px]" data-node-id="I4012:4792;4356:10693" data-name="Folder">
                    <img alt="" className="absolute inset-0 max-w-none object-cover pointer-events-none size-full" src={imgFolder} />
                  </div>
                </div>
                <div className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] [word-break:break-word] flex flex-col font-['SF_Pro:Regular'] font-normal justify-center leading-[0] relative shrink-0 text-[12px] text-center text-white whitespace-nowrap" data-node-id="4012:4793" style={{ fontVariationSettings: '"wdth" 100' }}>
                  <p className="leading-[16px]">Desktop</p>
                </div>
              </div>
            </div>
          </div>
          <div className="bg-[#0d2b09] content-stretch flex flex-col items-start p-px relative rounded-[10px] shrink-0" data-node-id="4012:4805">
            <div className="bg-[#0d2b09] border border-[#131313] border-solid content-stretch flex h-[36px] items-center justify-center overflow-clip px-[10px] relative rounded-[9px] shrink-0 w-full" data-node-id="4012:4806">
              <p className="[text-box-edge:cap_alphabetic] [text-box-trim:trim-both] [word-break:break-word] font-['SF_Pro:Medium'] font-[510] leading-[16px] overflow-hidden relative shrink-0 text-[#64dc21] text-[13px] text-ellipsis whitespace-nowrap" data-node-id="4012:4807" style={{ fontVariationSettings: '"wdth" 100' }}>
                Airufied!
              </p>
            </div>
          </div>
        </div>
      </div>
      <div className="-translate-x-1/2 absolute bg-[rgba(255,255,255,0.05)] content-stretch flex items-center justify-center left-[calc(50%+280px)] p-[5px] rounded-[67px] size-[40px] top-[14px]" data-node-id="4010:2691">
        <div className="grid-cols-[max-content] grid-rows-[max-content] inline-grid leading-[0] place-items-start relative shrink-0" data-node-id="4010:2692">
          <div className="bg-[#afafaf] col-1 h-[16px] ml-[7px] mt-0 relative row-1 w-[1.6px]" data-node-id="4010:2693" />
          <div className="col-1 flex h-[1.6px] items-center justify-center ml-0 mt-[7px] relative row-1 w-[16px]" data-node-id="4010:2694">
            <div className="flex-none rotate-90">
              <div className="bg-[#afafaf] h-[16px] relative w-[1.6px]" />
            </div>
          </div>
        </div>
      </div>
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
